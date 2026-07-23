// Copyright (C) 2024, 2025 Hydra-Pool Developers (see AUTHORS)
//
// This file is part of Hydra-Pool.
//
// Hydra-Pool is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free
// Software Foundation, either version 3 of the License, or (at your option)
// any later version.
//
// Hydra-Pool is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License along with
// Hydra-Pool. If not, see <https://www.gnu.org/licenses/>.

use bitcoin::consensus::encode::serialize_hex;
use bitcoin::hashes::Hash;
use clap::Parser;
use p2poolv2_api::start_api_server;
use p2poolv2_lib::accounting::stats::metrics;
use p2poolv2_lib::config::Config;
use p2poolv2_lib::logging::setup_logging;
use p2poolv2_lib::node::actor::NodeHandle;
use p2poolv2_lib::shares::chain::chain_store::ChainStore;
use p2poolv2_lib::shares::share_block::ShareBlock;
use p2poolv2_lib::store::Store;
use p2poolv2_lib::stratum::client_connections::start_connections_handler;
use p2poolv2_lib::stratum::emission::Emission;
use p2poolv2_lib::stratum::server::StratumServerBuilder;
use p2poolv2_lib::stratum::work::gbt::build_merkle_branches_for_template;
use p2poolv2_lib::stratum::work::gbt::start_gbt;
use p2poolv2_lib::stratum::work::notify::start_notify;
use p2poolv2_lib::stratum::work::tracker::start_tracker_actor;
use p2poolv2_lib::stratum::zmq_listener::{ZmqListener, ZmqListenerTrait};
use reqwest::Url;
use serde::Serialize;
use serde_json::json; // For building JSON if needed
use std::collections::HashMap;
use std::env;
use std::fs::File;
use std::io::Write;
use std::process::exit;
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::oneshot;
use tracing::debug;
use tracing::error;
use tracing::info;

/// Interval in seconds to poll for new block templates since the last zmq signal
const GBT_POLL_INTERVAL: u64 = 10; // seconds

/// Maximum number of pending shares from all clients connected to stratum server
const STRATUM_SHARES_BUFFER_SIZE: usize = 1000;

/// 100% donation in bips, skip address validation
const FULL_DONATION_BIPS: u16 = 10_000;

/// Notify channel enqueues requests to send notify updates to new
/// clients. If we have more than notify channel capacity of pending
/// clients in queue, some will be dropped.
const NOTIFY_CHANNEL_CAPACITY: usize = 1000;
/// Maximum number of pending shares queued for downstream high-difficulty API
const HIGH_DIFF_SHARES_BUFFER_SIZE: usize = 1000;

fn default_high_diff_submit_interval_secs() -> u64 {
    10
}

fn default_high_diff_adjust_interval_secs() -> u64 {
    30
}

fn default_high_diff_submit_queue_size() -> usize {
    1000
}

#[derive(Debug, Default)]
struct HydrapoolStratumLocalConfig {
    high_diff_share_submit_url: Option<Url>,
    gridpool_share_telemetry_url: Option<Url>,
    gridpool_adapter_token: Option<String>,
    high_diff_share_submit_interval_secs: u64,
    high_diff_share_adjust_interval_secs: u64,
    high_diff_share_submit_queue_size: usize,
}

impl HydrapoolStratumLocalConfig {
    fn with_defaults() -> Self {
        Self {
            high_diff_share_submit_url: None,
            gridpool_share_telemetry_url: None,
            gridpool_adapter_token: None,
            high_diff_share_submit_interval_secs: default_high_diff_submit_interval_secs(),
            high_diff_share_adjust_interval_secs: default_high_diff_adjust_interval_secs(),
            high_diff_share_submit_queue_size: default_high_diff_submit_queue_size(),
        }
    }
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "PascalCase")]
struct BootShareSubmission {
    miner_address: String,
    header_hex: String,
    coinbase_hex: String,
    merkle_path: Vec<String>,
    nonce: i64,
    difficulty: f64,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct GridPoolTelemetryBatch {
    source_instance: String,
    entries: Vec<GridPoolTelemetryEntry>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct GridPoolTelemetryEntry {
    channel_id: String,
    payout_address: String,
    username: String,
    window_start_utc: chrono::DateTime<chrono::Utc>,
    window_end_utc: chrono::DateTime<chrono::Utc>,
    accepted_share_count: u64,
    rejected_share_count: u64,
    accepted_work_difficulty: f64,
    fee_work_difficulty: f64,
    best_difficulty: f64,
}

struct TelemetryAccumulator {
    payout_address: String,
    username: String,
    window_start_utc: chrono::DateTime<chrono::Utc>,
    window_end_utc: chrono::DateTime<chrono::Utc>,
    accepted_share_count: u64,
    accepted_work_difficulty: f64,
    best_difficulty: f64,
}

/// Wait for shutdown signals (Ctrl+C, SIGTERM on Unix) or internal shutdown signal.
/// Returns when any shutdown signal is received.
#[cfg(unix)]
async fn wait_for_shutdown_signal(stopping_rx: oneshot::Receiver<()>) {
    let mut sigterm = tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
        .expect("Failed to set up SIGTERM handler");

    tokio::select! {
        _ = tokio::signal::ctrl_c() => {
            info!("Received Ctrl+C, initiating graceful shutdown...");
        }
        _ = sigterm.recv() => {
            info!("Received SIGTERM, initiating graceful shutdown...");
        }
        _ = stopping_rx => {
            info!("Node stopping due to internal signal...");
        }
    }
}

/// Wait for shutdown signals (Ctrl+C) or internal shutdown signal.
/// Returns when any shutdown signal is received.
#[cfg(not(unix))]
async fn wait_for_shutdown_signal(stopping_rx: oneshot::Receiver<()>) {
    tokio::select! {
        _ = tokio::signal::ctrl_c() => {
            info!("Received Ctrl+C, initiating graceful shutdown...");
        }
        _ = stopping_rx => {
            info!("Node stopping due to internal signal...");
        }
    }
}

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    #[arg(short, long)]
    config: String,
}

#[tokio::main]
async fn main() -> Result<(), String> {
    info!("Starting Hydrapool...");
    // Parse command line arguments
    let args = Args::parse();

    // Load configuration
    let config = Config::load(&args.config);
    if config.is_err() {
        let err = config.unwrap_err();
        error!("Failed to load config: {err}");
        return Err(format!("Failed to load config: {err}"));
    }
    let config = config.unwrap();
    let local_config = load_local_config(&args.config)?;
    // Configure logging based on config
    let logging_result = setup_logging(&config.logging);
    // hold guard to ensure logging is set up correctly
    let _guard = match logging_result {
        Ok(guard) => {
            info!("Logging set up successfully");
            guard
        }
        Err(e) => {
            error!("Failed to set up logging: {e}");
            return Err(format!("Failed to set up logging: {e}"));
        }
    };

    let genesis = ShareBlock::build_genesis_for_network(config.stratum.network);
    let store = Arc::new(Store::new(config.store.path.clone(), false).unwrap());
    let chain_store = Arc::new(ChainStore::new(
        store.clone(),
        genesis,
        config.stratum.network,
    ));

    let tip = chain_store.store.get_chain_tip();
    let height = chain_store.get_tip_height();
    info!("Latest tip {:?} at height {:?}", tip, height);

    let background_tasks_store = store.clone();
    p2poolv2_lib::store::background_tasks::start_background_tasks(
        background_tasks_store,
        Duration::from_secs(config.store.background_task_frequency_hours * 3600),
        Duration::from_secs(config.store.pplns_ttl_days * 3600 * 24),
    );

    let mut stratum_config = config.stratum.clone().parse().unwrap();
    let mut payout_file_path = stratum_config.payout_file_path.clone(); // Optional

    // If URL set, spawn fetcher to update file
    if let Some(ref url) = stratum_config.downstream_payout_url {
        // Assume you add this field too (see below)
        if payout_file_path.is_none() {
            payout_file_path = Some("/tmp/hydrapool_payouts.json".to_string()); // Default file
        }
        if let Some(ref file_path) = payout_file_path {
            let file_clone = file_path.clone();
            let url_clone = url.clone();
            let interval = Duration::from_secs(config.stratum.payout_refresh_interval);
            let network = stratum_config.network; // For addr validation if needed
            info!(
                "Starting downstream payout fetcher: url={} file={} interval={}s",
                url_clone,
                file_clone,
                interval.as_secs()
            );

            tokio::spawn(async move {
                loop {
                    if let Err(e) = fetch_and_write_payouts(&url_clone, &file_clone, network).await
                    {
                        debug!("API fetch/write failed: {}", e);
                    }
                    tokio::time::sleep(interval).await;
                }
            });
        }
    }

    // Set the parsed config's file path
    stratum_config.payout_file_path = payout_file_path;

    let bitcoinrpc_config = config.bitcoinrpc.clone();

    let (stratum_shutdown_tx, stratum_shutdown_rx) = tokio::sync::oneshot::channel();
    let (notify_tx, notify_rx) = tokio::sync::mpsc::channel(NOTIFY_CHANNEL_CAPACITY);
    let tracker_handle = start_tracker_actor();

    let notify_tx_for_gbt = notify_tx.clone();
    let bitcoinrpc_config_cloned = bitcoinrpc_config.clone();
    // Setup ZMQ publisher for block notifications
    let zmq_trigger_rx = match ZmqListener.start(&stratum_config.zmqpubhashblock) {
        Ok(rx) => rx,
        Err(e) => {
            error!("Failed to set up ZMQ publisher: {e}");
            return Err("Failed to set up ZMQ publisher".into());
        }
    };

    tokio::spawn(async move {
        if let Err(e) = start_gbt(
            bitcoinrpc_config_cloned,
            notify_tx_for_gbt,
            GBT_POLL_INTERVAL,
            stratum_config.network,
            zmq_trigger_rx,
        )
        .await
        {
            tracing::error!("Failed to fetch block template. Shutting down. \n {e}");
            exit(1);
        }
    });

    let connections_handle = start_connections_handler().await;
    let connections_cloned = connections_handle.clone();

    let tracker_handle_cloned = tracker_handle.clone();
    let store_for_notify = chain_store.clone();

    let cloned_stratum_config = stratum_config.clone();
    tokio::spawn(async move {
        info!("Starting Stratum notifier...");
        // This will run indefinitely, sending new block templates to the Stratum server as they arrive
        start_notify(
            notify_rx,
            connections_cloned,
            store_for_notify,
            tracker_handle_cloned,
            &cloned_stratum_config,
            None,
        )
        .await;
    });

    let (stratum_emissions_tx, stratum_emissions_rx) =
        tokio::sync::mpsc::channel::<Emission>(STRATUM_SHARES_BUFFER_SIZE);
    let (node_emissions_tx, node_emissions_rx) =
        tokio::sync::mpsc::channel::<Emission>(STRATUM_SHARES_BUFFER_SIZE);

    let boot_submit_url = local_config.high_diff_share_submit_url.clone();
    let high_diff_submit_interval_secs = local_config.high_diff_share_submit_interval_secs.max(1);
    let high_diff_adjust_interval_secs = local_config.high_diff_share_adjust_interval_secs.max(1);
    let high_diff_share_submit_queue_size = local_config
        .high_diff_share_submit_queue_size
        .max(1)
        .min(HIGH_DIFF_SHARES_BUFFER_SIZE);
    let telemetry_submitter = match (
        local_config.gridpool_share_telemetry_url.clone(),
        local_config.gridpool_adapter_token.clone(),
    ) {
        (Some(url), Some(token)) => {
            let (tx, rx) = tokio::sync::mpsc::channel::<GridPoolTelemetryBatch>(16);
            info!("GridPool vardiff telemetry enabled: url={}", url);
            tokio::spawn(start_gridpool_telemetry_submitter(url, token, rx));
            Some(tx)
        }
        (Some(_), None) => {
            info!("GridPool vardiff telemetry disabled: GRIDPOOL_ADAPTER_TOKEN is not set");
            None
        }
        _ => None,
    };

    if let Some(url) = boot_submit_url {
        info!(
            "High-difficulty share submit enabled: url={} target_interval={}s adjust_interval={}s",
            url, high_diff_submit_interval_secs, high_diff_adjust_interval_secs
        );
        let (boot_submit_tx, boot_submit_rx) =
            tokio::sync::mpsc::channel::<BootShareSubmission>(high_diff_share_submit_queue_size);
        tokio::spawn(start_boot_share_submitter(url, boot_submit_rx));
        tokio::spawn(forward_emissions_with_adaptive_threshold(
            stratum_emissions_rx,
            node_emissions_tx,
            Some(boot_submit_tx),
            telemetry_submitter,
            high_diff_submit_interval_secs,
            high_diff_adjust_interval_secs,
        ));
    } else {
        info!("High-difficulty share submit disabled");
        tokio::spawn(forward_emissions_with_adaptive_threshold(
            stratum_emissions_rx,
            node_emissions_tx,
            None,
            telemetry_submitter,
            high_diff_submit_interval_secs,
            high_diff_adjust_interval_secs,
        ));
    }

    let metrics_handle = match metrics::start_metrics(config.logging.stats_dir.clone()).await {
        Ok(handle) => handle,
        Err(e) => {
            return Err(format!("Failed to start metrics: {e}"));
        }
    };
    let metrics_cloned = metrics_handle.clone();
    let metrics_for_shutdown = metrics_handle.clone();
    let stats_dir_for_shutdown = config.logging.stats_dir.clone();
    let store_for_stratum = chain_store.clone();
    let tracker_handle_cloned = tracker_handle.clone();

    tokio::spawn(async move {
        let mut stratum_server = StratumServerBuilder::default()
            .shutdown_rx(stratum_shutdown_rx)
            .connections_handle(connections_handle.clone())
            .emissions_tx(stratum_emissions_tx)
            .hostname(stratum_config.hostname)
            .port(stratum_config.port)
            .start_difficulty(stratum_config.start_difficulty)
            .minimum_difficulty(stratum_config.minimum_difficulty)
            .maximum_difficulty(stratum_config.maximum_difficulty)
            .ignore_difficulty(stratum_config.ignore_difficulty)
            .validate_addresses(Some(
                stratum_config.donation.unwrap_or_default() != FULL_DONATION_BIPS,
            )) // 100% donation in bips, skip address validation
            .network(stratum_config.network)
            .version_mask(stratum_config.version_mask)
            .store(store_for_stratum)
            .build()
            .await
            .unwrap();
        info!("Starting Stratum server...");
        let result = stratum_server
            .start(
                None,
                notify_tx,
                tracker_handle_cloned,
                bitcoinrpc_config,
                metrics_cloned,
            )
            .await;
        if result.is_err() {
            error!("Failed to start Stratum server: {}", result.unwrap_err());
        }
        info!("Stratum server stopped");
    });

    let api_shutdown_tx = match start_api_server(
        config.api.clone(),
        chain_store.clone(),
        metrics_handle.clone(),
        tracker_handle,
        stratum_config.network,
        stratum_config.pool_signature,
    )
    .await
    {
        Ok(shutdown_tx) => shutdown_tx,
        Err(e) => {
            info!("Error starting server: {}", e);
            return Err("Failed to start API Server. Quitting.".into());
        }
    };
    info!(
        "API server started on host {} port {}",
        config.api.hostname, config.api.port
    );

    match NodeHandle::new(config, chain_store, node_emissions_rx, metrics_handle).await {
        Ok((node_handle, stopping_rx)) => {
            info!("Node started");

            wait_for_shutdown_signal(stopping_rx).await;

            info!("Node shutting down ...");

            // Shutdown node first to stop accepting new work
            if let Err(e) = node_handle.shutdown().await {
                error!("Error during node shutdown: {e}");
            }

            // Save metrics before shutdown to prevent data loss
            let metrics = metrics_for_shutdown.get_metrics().await;
            if let Err(e) = p2poolv2_lib::accounting::stats::pool_local_stats::save_pool_local_stats(
                &metrics,
                &stats_dir_for_shutdown,
            ) {
                error!("Failed to save metrics on shutdown: {e}");
            } else {
                info!("Metrics saved on shutdown");
            }

            stratum_shutdown_tx
                .send(())
                .expect("Failed to send shutdown signal to Stratum server");

            api_shutdown_tx
                .send(())
                .expect("Failed to send shutdown signal to API server");

            info!("Node stopped");
        }
        Err(e) => {
            error!("Failed to start node: {e}");
            return Err(format!("Failed to start node: {e}"));
        }
    }
    Ok(())
}

fn load_local_config(path: &str) -> Result<HydrapoolStratumLocalConfig, String> {
    let settings = config::Config::builder()
        .add_source(config::File::with_name(path))
        .build()
        .map_err(|e| format!("Failed to load local hydrapool config from {path}: {e}"))?;

    let mut local = HydrapoolStratumLocalConfig::with_defaults();

    local.high_diff_share_submit_url = settings
        .get_string("stratum.high_diff_share_submit_url")
        .ok()
        .and_then(|url| Url::parse(&url).ok());
    local.gridpool_share_telemetry_url = settings
        .get_string("stratum.gridpool_share_telemetry_url")
        .ok()
        .and_then(|url| Url::parse(&url).ok());
    local.gridpool_adapter_token = env::var("GRIDPOOL_ADAPTER_TOKEN")
        .ok()
        .filter(|value| !value.trim().is_empty());

    if let Ok(value) = settings.get_int("stratum.high_diff_share_submit_interval_secs") {
        local.high_diff_share_submit_interval_secs = value.max(1) as u64;
    }
    if let Ok(value) = settings.get_int("stratum.high_diff_share_adjust_interval_secs") {
        local.high_diff_share_adjust_interval_secs = value.max(1) as u64;
    }
    if let Ok(value) = settings.get_int("stratum.high_diff_share_submit_queue_size") {
        local.high_diff_share_submit_queue_size = value.max(1) as usize;
    }

    Ok(local)
}

async fn forward_emissions_with_adaptive_threshold(
    mut stratum_emissions_rx: tokio::sync::mpsc::Receiver<Emission>,
    node_emissions_tx: tokio::sync::mpsc::Sender<Emission>,
    boot_submit_tx: Option<tokio::sync::mpsc::Sender<BootShareSubmission>>,
    telemetry_submit_tx: Option<tokio::sync::mpsc::Sender<GridPoolTelemetryBatch>>,
    target_submit_interval_secs: u64,
    adjust_interval_secs: u64,
) {
    let target_submit_interval = Duration::from_secs(target_submit_interval_secs.max(1));
    let adjust_interval = Duration::from_secs(adjust_interval_secs.max(1));

    let mut current_threshold: u64 = 1;
    let mut threshold_calibrated = false;
    let mut observed_difficulties: Vec<u64> = Vec::new();
    let mut telemetry: HashMap<String, TelemetryAccumulator> = HashMap::new();
    let mut last_adjust_at = tokio::time::Instant::now();
    let mut seen_count: u64 = 0;
    let mut queued_count: u64 = 0;
    let mut below_threshold_count: u64 = 0;
    let mut dropped_count: u64 = 0;

    while let Some(emission) = stratum_emissions_rx.recv().await {
        seen_count = seen_count.saturating_add(1);
        let truediff = get_true_difficulty(&emission.header.block_hash()) as u64;
        observed_difficulties.push(truediff);
        record_telemetry_sample(&mut telemetry, &emission, truediff);

        let elapsed = last_adjust_at.elapsed();
        if elapsed >= adjust_interval {
            let new_threshold = recompute_threshold(
                &observed_difficulties,
                elapsed,
                target_submit_interval,
                current_threshold,
            );
            if new_threshold != current_threshold {
                debug!(
                    "Adjusted high-diff share threshold from {} to {} using {} samples over {:.1}s",
                    current_threshold,
                    new_threshold,
                    observed_difficulties.len(),
                    elapsed.as_secs_f64()
                );
            }
            if boot_submit_tx.is_some() {
                info!(
                    "High-diff relay window: seen={} queued={} below_threshold={} dropped={} threshold={} target={}s",
                    seen_count,
                    queued_count,
                    below_threshold_count,
                    dropped_count,
                    current_threshold,
                    target_submit_interval.as_secs()
                );
            }
            current_threshold = new_threshold;
            threshold_calibrated = true;
            if let Some(ref tx) = telemetry_submit_tx {
                let batch = build_telemetry_batch(&mut telemetry);
                if !batch.entries.is_empty() && tx.try_send(batch).is_err() {
                    debug!("Dropped GridPool telemetry batch because submit queue is full");
                }
            }
            observed_difficulties.clear();
            last_adjust_at = tokio::time::Instant::now();
            seen_count = 0;
            queued_count = 0;
            below_threshold_count = 0;
            dropped_count = 0;
        }

        if threshold_calibrated && let Some(ref tx) = boot_submit_tx {
            if truediff >= current_threshold {
                if let Some(payload) = build_boot_submission(&emission, truediff) {
                    let miner = payload.miner_address.clone();
                    let difficulty = payload.difficulty;
                    if tx.try_send(payload).is_err() {
                        dropped_count = dropped_count.saturating_add(1);
                        debug!("Dropped high-diff share submission because submit queue is full");
                    } else {
                        queued_count = queued_count.saturating_add(1);
                        debug!(
                            "Queued high-diff share for submit miner={} diff={} threshold={}",
                            miner, difficulty, current_threshold
                        );
                    }
                }
            } else {
                below_threshold_count = below_threshold_count.saturating_add(1);
            }
        }

        if node_emissions_tx.send(emission).await.is_err() {
            info!("Node emission channel closed. Stopping emission forwarder.");
            break;
        }
    }
}

fn record_telemetry_sample(
    telemetry: &mut HashMap<String, TelemetryAccumulator>,
    emission: &Emission,
    achieved_difficulty: u64,
) {
    let payout_address = emission.pplns.btcaddress.clone().unwrap_or_default();
    if payout_address.is_empty() {
        return;
    }

    let username = emission.pplns.workername.clone().unwrap_or_default();
    let channel_id = if username.is_empty() {
        payout_address.clone()
    } else {
        format!("{payout_address}.{username}")
    };
    let now = chrono::Utc::now();
    let entry = telemetry
        .entry(channel_id)
        .or_insert_with(|| TelemetryAccumulator {
            payout_address,
            username,
            window_start_utc: now,
            window_end_utc: now,
            accepted_share_count: 0,
            accepted_work_difficulty: 0.0,
            best_difficulty: 0.0,
        });
    entry.window_end_utc = now;
    entry.accepted_share_count = entry.accepted_share_count.saturating_add(1);
    entry.accepted_work_difficulty += emission.pplns.difficulty as f64;
    entry.best_difficulty = entry.best_difficulty.max(achieved_difficulty as f64);
}

fn build_telemetry_batch(
    telemetry: &mut HashMap<String, TelemetryAccumulator>,
) -> GridPoolTelemetryBatch {
    let entries = telemetry
        .drain()
        .map(|(channel_id, entry)| GridPoolTelemetryEntry {
            channel_id,
            payout_address: entry.payout_address,
            username: entry.username,
            window_start_utc: entry.window_start_utc,
            window_end_utc: entry.window_end_utc,
            accepted_share_count: entry.accepted_share_count,
            rejected_share_count: 0,
            accepted_work_difficulty: entry.accepted_work_difficulty,
            fee_work_difficulty: 0.0,
            best_difficulty: entry.best_difficulty,
        })
        .collect();
    GridPoolTelemetryBatch {
        source_instance: "hydrapool-local".to_string(),
        entries,
    }
}

fn recompute_threshold(
    observed_difficulties: &[u64],
    elapsed: Duration,
    target_submit_interval: Duration,
    current_threshold: u64,
) -> u64 {
    if observed_difficulties.is_empty() {
        return (current_threshold / 2).max(1);
    }

    let target_count =
        ((elapsed.as_secs_f64() / target_submit_interval.as_secs_f64()).round() as usize).max(1);
    let mut sorted = observed_difficulties.to_vec();
    sorted.sort_unstable_by(|a, b| b.cmp(a));
    let idx = target_count
        .saturating_sub(1)
        .min(sorted.len().saturating_sub(1));
    sorted[idx].max(1)
}

/// Use bitcoin mainnet max attainable target to convert the hash into difficulty.
/// This mirrors p2poolv2's truediffone-based share difficulty metric.
fn get_true_difficulty(hash: &bitcoin::BlockHash) -> u128 {
    let mut bytes = hash.as_byte_array().to_vec();
    bytes.reverse();
    let diff = u128::from_str_radix(&hex::encode(&bytes[..16]), 16).unwrap();
    (0xFFFF_u128 << (208 - 128)) / diff
}

fn build_boot_submission(emission: &Emission, truediff: u64) -> Option<BootShareSubmission> {
    let btcaddress = emission.pplns.btcaddress.clone().unwrap_or_default();
    if btcaddress.is_empty() {
        return None;
    }
    let workername = emission.pplns.workername.clone().unwrap_or_default();
    let miner_address = if workername.is_empty() {
        btcaddress
    } else {
        format!("{btcaddress}.{workername}")
    };

    let merkle_path = build_merkle_branches_for_template(&emission.blocktemplate)
        .into_iter()
        .map(|h| h.to_string())
        .collect::<Vec<_>>();

    Some(BootShareSubmission {
        miner_address,
        header_hex: serialize_hex(&emission.header),
        coinbase_hex: serialize_hex(&emission.coinbase),
        merkle_path,
        nonce: emission.header.nonce as i64,
        difficulty: truediff as f64,
    })
}

async fn start_boot_share_submitter(
    submit_url: Url,
    mut boot_submit_rx: tokio::sync::mpsc::Receiver<BootShareSubmission>,
) {
    let client = reqwest::Client::new();
    while let Some(payload) = boot_submit_rx.recv().await {
        let mut attempt: u8 = 0;
        loop {
            attempt = attempt.saturating_add(1);
            let response = client
                .post(submit_url.clone())
                .header("X-GridPool-Mining-Source", "hydrapool")
                .json(&payload)
                .send()
                .await;
            match response {
                Ok(resp) if resp.status().is_success() => {
                    debug!(
                        "Submitted high-diff share to {} miner={} diff={} status={}",
                        submit_url,
                        payload.miner_address,
                        payload.difficulty,
                        resp.status()
                    );
                    break;
                }
                Ok(resp) => {
                    let status = resp.status();
                    let response_body = resp.text().await.unwrap_or_default();
                    if status.is_client_error() || attempt >= 3 {
                        info!(
                            "Failed submitting high-diff share to {} status={} reason={} after {} attempts",
                            submit_url, status, response_body, attempt
                        );
                        break;
                    }
                }
                Err(e) => {
                    if attempt >= 3 {
                        debug!(
                            "Failed submitting high-diff share to {} error={} after {} attempts",
                            submit_url, e, attempt
                        );
                        break;
                    }
                }
            }
            tokio::time::sleep(Duration::from_millis(250 * u64::from(attempt))).await;
        }
    }
}

async fn start_gridpool_telemetry_submitter(
    submit_url: Url,
    adapter_token: String,
    mut telemetry_rx: tokio::sync::mpsc::Receiver<GridPoolTelemetryBatch>,
) {
    let client = reqwest::Client::new();
    while let Some(batch) = telemetry_rx.recv().await {
        let response = client
            .post(submit_url.clone())
            .header("X-GridPool-Adapter-Token", &adapter_token)
            .header("X-GridPool-Adapter-Type", "hydrapool")
            .json(&batch)
            .send()
            .await;
        match response {
            Ok(resp) if resp.status().is_success() => {
                debug!(
                    "Submitted GridPool vardiff telemetry entries={} status={}",
                    batch.entries.len(),
                    resp.status()
                );
            }
            Ok(resp) => {
                let status = resp.status();
                let body = resp.text().await.unwrap_or_default();
                info!(
                    "Failed submitting GridPool vardiff telemetry status={} reason={}",
                    status, body
                );
            }
            Err(error) => {
                info!("Failed submitting GridPool vardiff telemetry: {}", error);
            }
        }
    }
}

async fn fetch_and_write_payouts(
    url: &reqwest::Url, // ← change to &Url
    file_path: &str,
    _network: bitcoin::Network,
) -> Result<(), Box<dyn std::error::Error>> {
    debug!("Fetching payouts from {} ...", url);
    let client = reqwest::Client::new();
    let resp = client.get(url.clone()).send().await?; // ← works directly with &Url
    if !resp.status().is_success() {
        return Err(format!("HTTP {} from {}", resp.status(), url).into());
    }
    let json: serde_json::Value = resp.json().await?;

    // Accept multiple key variants from downstream APIs.
    let raw_payouts = json["payouts"]
        .as_array()
        .or_else(|| json["Payouts"].as_array())
        .or_else(|| json["WinnersList"].as_array())
        .ok_or("Missing payouts/Payouts/WinnersList")?
        .clone();

    // Normalize payout objects so p2poolv2 file mode can parse them.
    // p2poolv2 expects each payout to have "Address" and "Value" keys.
    let mut payouts = Vec::with_capacity(raw_payouts.len());
    for entry in raw_payouts {
        let address = entry["Address"]
            .as_str()
            .or_else(|| entry["address"].as_str())
            .or_else(|| entry["MinerAddress"].as_str())
            .ok_or("Missing Address/address/MinerAddress in payout entry")?;
        let value = entry["Value"]
            .as_u64()
            .or_else(|| entry["value"].as_u64())
            .ok_or("Missing Value/value in payout entry")?;
        payouts.push(json!({
            "Address": address,
            "Value": value
        }));
    }

    let on_deck = if !json["OnDeckList"].is_null() {
        json["OnDeckList"].clone()
    } else {
        serde_json::Value::Null
    };
    let best_share = if !json["BestShare"].is_null() {
        json["BestShare"].clone()
    } else {
        serde_json::Value::Null
    };
    let updated_json = json!({
        // p2poolv2 loader currently expects "payouts"
        "payouts": payouts,
        "OnDeckList": on_deck,
        "BestShare": best_share
    });

    let mut file = File::create(file_path)?;
    file.write_all(updated_json.to_string().as_bytes())?;
    info!(
        "Updated payout file from {} -> {} ({} payouts)",
        url,
        file_path,
        updated_json["payouts"].as_array().map_or(0, |a| a.len())
    );
    Ok(())
}
