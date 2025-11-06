{ hydrapool }:

{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.hydrapool;
  format = pkgs.formats.toml { };

  # Generate configuration file
  configFile = format.generate "hydrapool.toml" {
    store = {
      path = cfg.dataDir + "/store.db";
      background_task_frequency_hours = cfg.backgroundTaskFrequencyHours;
      pplns_ttl_days = cfg.pplnsTtlDays;
    };

    stratum = {
      hostname = cfg.stratum.host;
      port = cfg.stratum.port;
      start_difficulty = cfg.stratum.startDifficulty;
      minimum_difficulty = cfg.stratum.minimumDifficulty;
      bootstrap_address = cfg.bootstrapAddress;
      network = cfg.bitcoin.network;
      version_mask = cfg.versionMask;
      difficulty_multiplier = cfg.difficultyMultiplier;
      pool_signature = cfg.poolSignature;
    }
    // optionalAttrs (cfg.poolFee > 0) { fee = cfg.poolFee; }
    // optionalAttrs (cfg.donationAddress != null) {
      donation_address = cfg.donationAddress;
      donation = cfg.donationFee;
    };

    bitcoinrpc = {
      url = cfg.bitcoin.rpcUrl;
      username = cfg.bitcoin.rpcUser;
      password = cfg.bitcoin.rpcPassword;
    };

    logging = {
      level = cfg.logLevel;
      stats_dir = cfg.dataDir + "/stats";
    }
    // optionalAttrs cfg.enableFileLogging {
      file = cfg.logDir + "/hydrapool.log";
    };

    api = {
      hostname = cfg.api.host;
      port = cfg.api.port;
      auth_user = cfg.api.authUser;
      auth_token = cfg.api.authToken;
    };
  };

  # Prometheus configuration
  prometheusConfig = pkgs.writeText "prometheus.yml" ''
    global:
      scrape_interval: 15s

    scrape_configs:
      - job_name: 'hydrapool'
        static_configs:
          - targets: ['localhost:${toString cfg.api.port}']
        basic_auth:
          username: '${cfg.api.authUser}'
          password: '${cfg.api.authToken}'
  '';

  # Grafana configuration
  grafanaConfig = {
    server = {
      http_addr = "127.0.0.1";
      http_port = cfg.grafana.port;
      domain = cfg.grafana.domain;
    };

    security = {
      admin_user = cfg.grafana.adminUser;
      admin_password = cfg.grafana.adminPassword;
      disable_gravatar = true;
    };

    auth.anonymous = {
      enabled = true;
      org_role = "Viewer";
    };

    users = {
      allow_sign_up = false;
    };

    dashboards = {
      default_home_dashboard_path = "${pkgs.hydrapool}/share/grafana/dashboards/pool.json";
    };
  };

in
{
  options.services.hydrapool = {
    enable = mkEnableOption "Hydra-Pool Bitcoin mining pool";

    package = mkOption {
      type = types.package;
      default = hydrapool;
      description = "Hydra-Pool package to use.";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/hydrapool";
      description = "Directory for Hydra-Pool data.";
    };

    logDir = mkOption {
      type = types.str;
      default = "/var/log/hydrapool";
      description = "Directory for Hydra-Pool logs.";
    };

    user = mkOption {
      type = types.str;
      default = "hydrapool";
      description = "User account under which Hydra-Pool runs.";
    };

    group = mkOption {
      type = types.str;
      default = "hydrapool";
      description = "Group under which Hydra-Pool runs.";
    };

    bootstrapAddress = mkOption {
      type = types.str;
      description = "Bitcoin address for early block payouts.";
    };

    poolFee = mkOption {
      type = types.ints.between 0 1000;
      default = 0;
      description = "Pool operator fee in basis points (100 = 1%).";
    };

    donationAddress = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Developer donation address.";
    };

    donationFee = mkOption {
      type = types.ints.between 0 500;
      default = 50;
      description = "Developer donation in basis points (100 = 1%).";
    };

    difficultyMultiplier = mkOption {
      type = types.floats.between 0.1 10.0;
      default = 1.0;
      description = "PPLNS window difficulty multiplier.";
    };

    poolSignature = mkOption {
      type = types.str;
      default = "hydrapool";
      description = "Pool signature for block identification (max 16 bytes).";
    };

    versionMask = mkOption {
      type = types.str;
      default = "1fffe000";
      description = "Version mask for mining.";
    };

    backgroundTaskFrequencyHours = mkOption {
      type = types.ints.between 1 168;
      default = 24;
      description = "Background task frequency in hours.";
    };

    pplnsTtlDays = mkOption {
      type = types.ints.between 1 30;
      default = 7;
      description = "PPLNS share TTL in days.";
    };

    logLevel = mkOption {
      type = types.enum [
        "error"
        "warn"
        "info"
        "debug"
        "trace"
      ];
      default = "info";
      description = "Logging level.";
    };

    enableFileLogging = mkOption {
      type = types.bool;
      default = true;
      description = "Enable file logging.";
    };

    stratum = {
      host = mkOption {
        type = types.str;
        default = "0.0.0.0";
        description = "Stratum server host.";
      };

      port = mkOption {
        type = types.port;
        default = 3333;
        description = "Stratum server port.";
      };

      startDifficulty = mkOption {
        type = types.ints.positive;
        default = 1;
        description = "Starting mining difficulty.";
      };

      minimumDifficulty = mkOption {
        type = types.ints.positive;
        default = 1;
        description = "Minimum mining difficulty.";
      };
    };

    bitcoin = {
      network = mkOption {
        type = types.enum [
          "main"
          "testnet4"
          "signet"
        ];
        default = "signet";
        description = "Bitcoin network to use.";
      };

      rpcUrl = mkOption {
        type = types.str;
        description = "Bitcoin RPC URL.";
      };

      rpcUser = mkOption {
        type = types.str;
        description = "Bitcoin RPC username.";
      };

      rpcPassword = mkOption {
        type = types.str;
        description = "Bitcoin RPC password.";
      };
    };

    api = {
      host = mkOption {
        type = types.str;
        default = "0.0.0.0";
        description = "API server host.";
      };

      port = mkOption {
        type = types.port;
        default = 46884;
        description = "API server port.";
      };

      authUser = mkOption {
        type = types.str;
        default = "hydrapool";
        description = "API authentication username.";
      };

      authToken = mkOption {
        type = types.str;
        description = "API authentication token.";
      };
    };

    enablePrometheus = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Prometheus monitoring.";
    };

    enableGrafana = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Grafana dashboard.";
    };

    grafana = {
      port = mkOption {
        type = types.port;
        default = 3000;
        description = "Grafana web interface port.";
      };

      domain = mkOption {
        type = types.str;
        default = "localhost";
        description = "Grafana domain.";
      };

      adminUser = mkOption {
        type = types.str;
        default = "admin";
        description = "Grafana admin username.";
      };

      adminPassword = mkOption {
        type = types.str;
        default = "admin";
        description = "Grafana admin password.";
      };
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open firewall ports for Hydra-Pool services.";
    };
  };

  config = mkIf cfg.enable {
    # User and group
    users.users = mkIf (cfg.user == "hydrapool") {
      hydrapool = {
        isSystemUser = true;
        group = cfg.group;
        description = "Hydra-Pool daemon user";
        home = cfg.dataDir;
        createHome = true;
      };
    };

    users.groups = mkIf (cfg.group == "hydrapool") {
      hydrapool = { };
    };

    # Directories
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.logDir} 0750 ${cfg.user} ${cfg.group} -"
    ];

    # Hydra-Pool service
    systemd.services.hydrapool = {
      description = "Hydra-Pool Bitcoin mining pool";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        Restart = "on-failure";
        RestartSec = 5;
        ExecStart = "${cfg.package}/bin/hydrapool --config ${configFile}";
        Environment = [ "RUST_LOG=${cfg.logLevel}" ];
        WorkingDirectory = cfg.dataDir;
        ReadOnlyPaths = [ configFile ];
        ReadWritePaths = [
          cfg.dataDir
          cfg.logDir
        ];
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = true;
      };

      # Wait for Bitcoin node if configured
      unitConfig = {
        After = mkIf (cfg.bitcoin.rpcUrl != "") [ "bitcoind.service" ];
        Wants = mkIf (cfg.bitcoin.rpcUrl != "") [ "bitcoind.service" ];
      };
    };

    # Prometheus service
    systemd.services.prometheus-hydrapool = mkIf cfg.enablePrometheus {
      description = "Prometheus for Hydra-Pool";
      after = [
        "network.target"
        "hydrapool.service"
      ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        Restart = "on-failure";
        RestartSec = 5;
        ExecStart = "${pkgs.prometheus}/bin/prometheus --config.file=${prometheusConfig} --storage.tsdb.path=${cfg.dataDir}/prometheus";
        WorkingDirectory = cfg.dataDir;
        ReadWritePaths = [ cfg.dataDir ];
        PrivateTmp = true;
        ProtectSystem = "strict";
      };
    };

    # Grafana service
    systemd.services.grafana-hydrapool = mkIf cfg.enableGrafana {
      description = "Grafana for Hydra-Pool";
      after = [
        "network.target"
        "prometheus-hydrapool.service"
      ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        Restart = "on-failure";
        RestartSec = 5;
        ExecStart = "${pkgs.grafana}/bin/grafana server --config=${
          pkgs.writeText "grafana.ini" (lib.generators.toINI { } grafanaConfig)
        }";
        WorkingDirectory = cfg.dataDir;
        ReadWritePaths = [ cfg.dataDir ];
        PrivateTmp = true;
        ProtectSystem = "strict";
      };
    };

    # Firewall configuration
    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [
        cfg.stratum.port
        cfg.api.port
      ]
      ++ optional cfg.enablePrometheus 9090
      ++ optional cfg.enableGrafana cfg.grafana.port;
    };

    # Package dependencies
    environment.systemPackages =
      with pkgs;
      [
        cfg.package
      ]
      ++ optional cfg.enablePrometheus prometheus
      ++ optional cfg.enableGrafana grafana;
  };
}
