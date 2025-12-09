# Hydrapool

[Hydrapool](https://hydrapool.org) is an open Source Bitcoin Mining
Pool with support for solo mining and PPLNS accounting.

We have an instance mining on mainnet at
[test.hydrapool.org](https://test.hydrapool.org). But we hope you'll
run a pool for yourself. See below on [how to run your own instance](#run). We
only accomodate up to 100 users atm for coinbase and block weight
reasons, workers are limited by your hardware.

## Features

1. Run a private solo pool or a private PPLNS pool for your community
   of miners.
2. Payouts are made directly from coinbase - pool operator doesn't
   custody any funds. No need to trust the pool operator.
3. Let users download and validate the accounting of shares. We
   provide an API for the same. See [API Server](#api)
3. Prometheus and Grafana based dashboard for pool, user and worker
   hashrates and uptimes.
4. Use any bitcoin node that supports bitcoin RPC.
5. Implemented in Rust, for ease of extending the pool with novel
   accounting and payout schemes.
6. Open source with AGPLv3. Feel free to extend and/or make changes.

<a id="run"></a>
# Running Your Own Hydrapool Instance

## Run with Docker

We provide Dockerfile and docker compose files to run hydrapool using
docker.

### Download docker compose and pool config file

```bash
curl --proto '=https' --tlsv1.2 -LsSf -o docker-compose.yml https://github.com/256foundation/hydrapool/releases/latest/download/docker-compose.yml
curl --proto '=https' --tlsv1.2 -LsSf -o config.toml https://github.com/256foundation/hydrapool/releases/latest/download/config-example.toml
```

### Edit config.toml
Edit the file to provide details for your own bitcoin node.

At the very least you will need to edit bitcoinrpc, zmqpubhashblock
and network (signet/main) to match your bitcoin node's settings. If
you use main network, change the bootstrap_address too.

### Edit bitcoin.conf
You potentially need to reconfigure your Bitcoin node to allow RPC access from
the network location at which Hydrapool is running.

The provided docker-compose.yml runs Hydrapool and the monitoring containers
on an isolated, bridged network. Docker typically uses a `/16` subnet from the
`172.16.0.0/12` private network range, with a gateway to the host at
`172.16.0.1`, `172.17.0.1`, ... . For the case where the Bitcoin node and
Docker are on the same machine, docker-compose.yml exposes the special
hostname `host.docker.internal` inside the Hydrapool container, which resolves
to the gateway address. This special hostname is used in Bitcoin node URLs in
Hydrapool's config.toml.

If the Bitcoin node is on the same host as Docker, configure the Bitcoin node
to accept connections from the bridged network, and allow access from addresses
in the bridged network's subnet. For example, Bitcoin Core would require
something like:
```
# bitcoin.conf

....

# allow connections from all interfaces, not just localhost
rpcbind=0.0.0.0

# allow Docker's bridged networks (for Hydrapool)
rpcallowip=172.16.0.0/12
```

If the Bitcoin node is on a different host than Docker, configure Hydrapool's
Bitcoin node URLs to point to that host. The Bitcoin node must accept
connections and allow RPC from the Docker host, since container traffic will be
NATed and appear to originate from the Docker host's IP address.

### Start pool
```bash
docker compose -f docker-compose.yml up
```

The above will start hydrapool stratum server on port 3333. A
monitoring dashboard on port 3000. If you are running on localhost,
`stratum://localhost:3333` and dashboard at
`http://localhost::3000`.

# Dashboards

## Pool Dashboard

The `Pool` dashboard shows the hashrate of the pool, the shares per
second, max difficulty reached by any of the workers. It also charts
the total number of users and workers in the pool over time and shows
the hashrate distribution between users mining on the pool.

![Pool Dashboard Preview](./docs/images/pool_dashboard.png)

## Users and Hashrate Dashboard

Th users dashboard shows the stats for a selected user. The current
dashboard shows all users btcaddresses mining on the pool, and there
is a private dashboard where you have to provide the user's btcaddress
to view stats. By default the public dashboard is used.

The dashboard shows the hashrate of the all their workers as well as
individual hashrate for all their workers. They can also filter their
workers by selecting specific workers from the workers drop down on
the top.

![Users Dashboard Preview](./docs/images/users_dashboard.png)

## Public Dashboard

To provide public facing dashboard, we recommend using nginx/apache as
a reverse proxy and running the dashboard as a system service.

Also see the section on securing the server for securing your API
server.

# Verify Docker Image Signatures

To verify docker images [install
cosign](https://docs.sigstore.dev/cosign/system_config/installation/)
and then verify using:

```bash
cosign verify \
    --certificate-identity-regexp=github.com/256foundation \
    ghcr.io/256-foundation/hydrapool:<TAG>
```

# Configuring `blockmaxweight` on Bitcoin

When mining with Hydrapool you need to leave enough room in the block
for that coinbase transaction.  Otherwise, Bitcoin Core may reject
your block template for exceeding the default maximum block weight of
**4,000,000 weight units (WU)**.

The parameter `blockmaxweight` in your `bitcoin.conf` limits how much
of the block is used by regular transactions. The remaining weight
ensures the coinbase transaction fits without exceeding consensus
limits.

The following table provides approximate values for different numbers
of **P2PKH** outputs in the coinbase. Adjust as needed for your own
setup.

| # of P2PKH outputs | Approx. coinbase size | Approx. coinbase weight | Suggested blockmaxweight |
|--------------------:|----------------------:|-------------------------:|--------------------------:|
| 20                 | ~732 bytes            | ~2,928 WU                | `3997000` |
| 100                | ~3,452 bytes          | ~13,808 WU               | `3986000` |
| 200                | ~6,852 bytes          | ~27,408 WU               | `3972500` |
| 500                | ~17,052 bytes         | ~68,208 WU               | `3930000` |
| 1000               | ~34,052 bytes         | ~136,208 WU              | `3860000` |

**Notes:**
- Default Bitcoin Core `blockmaxweight` = **4,000,000**.
- These estimates assume a standard **P2PKH** output (~34 bytes each)
  and a short coinbase scriptSig.
- If your coinbase uses **SegWit outputs (P2WPKH/P2WSH)**, you can
  reserve slightly less space.
- You can inspect your actual coinbase transaction size using
  `getblocktemplate` → `coinbasevalue` / `coinbasetxn` or by decoding
  it with `decoderawtransaction`.

Example configuration for `bitcoin.conf`:

```ini
# Reserve space for up to 500 P2PKH outputs in the coinbase
blockmaxweight=3930000
```

<a id="secure"></a>
# Securing your Server

If you provide public access to your api server, you can require
authentication to access the server. Edit the `auth_user` and
`auth_token` in config.toml.

We provide a command line tool to generate the salt and hashed
password to use in your config file.

```
docker compose run --rm hydrapool-cli gen-auth <USERNAME> <PASSWORD>
```

The above will generate config lines for pasting into your
config.toml.

Once the password is changed, you need to share that with your
prometheus setup. The same credentials will also be used to access the
API Server.

To update prometheus with your new credentials:

1. Copy the prometheus configuration template:
```bash
cp prometheus/prometheus.yml docker/prometheus.yml
```
2. Edit `docker/prometheus.yml` and change the username and password to match what was output by hydrapool_cli above:
```yaml
    basic_auth:
      username: '<USERNAME>'
      password: '<PASSWORD>'
```
3. Restart the prometheus service:
```bash
docker compose restart prometheus
```

Note: By default, prometheus uses the built-in configuration with credentials `hydrapool/hydrapool`. Creating a custom `docker/prometheus.yml` file overrides this default configuration.

<a id="api"></a>
# API Server

When you start the mining pool an API server is also started on the
port you specify in the config file.

The API Server is secured using the credentials you provide in the
config file. These credentials are used by prometheus to build the
dashboard and for your users to download shares for validating the
accounting and payouts.

Go to `http://<your_server_ip>:<your_api_server_port>/pplns_shares` to
download a json file of all the PPLNS Shares tracked by the pool for
distributing the block rewards.

The above URL accepts optional query parameters `start_time` and
`end_time` in RFC3339 format, e.g. `1996-12-19T16:39:57-08:00` to
limit the range of pplns shares to download.

To expose the API Server to public, we recommend using nginx as a
reverse proxy for the port, just like for the prometheus/grafana
dashboard.


# Other Options to Run Hydrapool

## Build from Source

To build from source, download this repo and build using cargo:
```bash
git clone https://github.com/256-foundation/Hydra-Pool/
cargo build --release
```
Then enter the settings for your particular node setup in config.toml, and generate an authorization token as explained above.

Finally, run from target directory.

```bash
./target/release/hydrapool
```
To test it, you can send an API command using curl. 
First, generate a Base64 string of your credentials:
```bash
echo -n 'YOUR_USERNAME:YOUR_PASSWORD' | base64
```
This will return a string.  Copy it and use it here:
```bash
curl -H "Authorization: Basic <BASE64_STRING>" http://localhost:46884/health
```

### Troubleshooting
If you have any issues, these might help:
#### Rust Version 
First, verify your Rust version is at least 1.88.0
```bash
rustc --version
```
If you need to update rust, it is recommended to use the official install script from 'https://rust-lang.org/tools/install/'
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```
On some Ubuntu installations (including 22.04 LTS), there may be an older version of Rust preinstalled, but the latest versions are not accessible from the standard apt or snap repositories.  For the official install script to run, you may need to first manually remove older versions of Rust:
```bash
sudo apt remove rustc cargo libstd-rust-dev
sudo apt autoremove
```
To remove snap versions, first check for snap entries named "rust", "rustc", or "rustup", then remove it ("rust" in this example):
```bash
snap list
sudo snap remove rust
```
Then, you may want to remove any old conflicting files as well:
```bash
# Remove the old, possibly conflicting files installed by previous rustups
rm -rf "$HOME/.cargo" "$HOME/.rustup"

# Start a fresh shell session to clear any old environment variables
exec $SHELL
```
Finally, run the official install script again. 

#### Missing libraries
If you get build errors, you may also need to update certain OpenSSL dev libraries and libclang libraries:
```bash
sudo apt update
sudo apt install libssl-dev pkg-config
sudo apt install clang libclang-dev
```
Then retry the build:
```bash
cargo clean
cargo build --release
```


## Install Hydrapool Binaries

```bash
curl --proto '=https' --tlsv1.2 -LsSf https://github.com/256-Foundation/Hydra-Pool/releases/latest/download/hydrapool-installer.sh | sh
```

The above will install two binaries in your path:

1. `hydrapool` - the binary to start the pool.
2. `hydrapool_cli` - a utility to query the state of the pool, generate authentication tokens etc.

Both binaries come with the `--help` option that document the other
options and commands they support.

Binaries are available on the
[releases](https://github.com/256-Foundation/Hydra-Pool/releases)
page. We provide Linux, Windows and MacOS binaries. Go to releases
page to access an older release.

To run dashboard, we still recommned using docker

```
docker compose up -d ghcr.io/256foundation/hydrapool-prometheus
docker compose up -d ghcr.io/256foundation/hydrapool-grafana
```
