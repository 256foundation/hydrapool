# Stage 1: Build Hydra-Pool from source
FROM rust:1.88-slim-bullseye AS builder

RUN apt-get update && apt-get install -y \
    build-essential \
    clang \
    pkg-config \
    libzmq3-dev \
    git \
    cmake \
    libzstd-dev \
    libsnappy-dev \
    libbz2-dev \
    liblz4-dev \
    zlib1g-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /hydrapool

COPY src/ ./src/
COPY Cargo.lock Cargo.toml ./

RUN cargo build --release

# Stage 2: Grab Prometheus binary
FROM prom/prometheus:v3.6.0 AS prometheus

# Stage 3: Grab Grafana
FROM grafana/grafana:12.2.0 AS grafana

# Stage 4: Runtime image
FROM debian:bullseye-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libzmq5 \
    libssl1.1 \
    libzstd1 \
    libsnappy1v5 \
    libbz2-1.0 \
    liblz4-1 \
    ca-certificates \
    wget \
    curl \
    supervisor \
    jq \
    netcat-openbsd \
    tini \
    && rm -rf /var/lib/apt/lists/*

# Install yq (not available in Debian Bullseye repos)
ARG TARGETARCH
RUN YQ_ARCH=$(echo ${TARGETARCH} | sed 's/amd64/amd64/;s/arm64/arm64/') && \
    wget -qO /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/v4.44.6/yq_linux_${YQ_ARCH}" && \
    chmod +x /usr/local/bin/yq

# Create hydrapool user
RUN groupadd --system hydrapool && \
    useradd --system --gid hydrapool --home-dir /data/hydrapool \
    --no-create-home --shell /usr/sbin/nologin hydrapool

# Copy Hydra-Pool binaries
COPY --from=builder /hydrapool/target/release/hydrapool /usr/local/bin/
COPY --from=builder /hydrapool/target/release/hydrapool_cli /usr/local/bin/
RUN chmod +x /usr/local/bin/hydrapool /usr/local/bin/hydrapool_cli

# Copy Prometheus binary
COPY --from=prometheus /bin/prometheus /usr/local/bin/prometheus
COPY --from=prometheus /bin/promtool /usr/local/bin/promtool
RUN chmod +x /usr/local/bin/prometheus /usr/local/bin/promtool

# Copy Grafana
COPY --from=grafana /usr/share/grafana /usr/share/grafana
COPY --from=grafana /run.sh /usr/share/grafana/run.sh
RUN ln -s /usr/share/grafana/bin/grafana /usr/local/bin/grafana-server || \
    ln -s /usr/share/grafana/bin/grafana-server /usr/local/bin/grafana-server || true

# Copy Prometheus config template
COPY prometheus/prometheus.yml /etc/prometheus/prometheus.yml.template

# Copy Grafana provisioning and dashboards
COPY prometheus/grafana/provisioning/ /etc/grafana/provisioning/
COPY prometheus/grafana/dashboards/ /etc/grafana/dashboards/

# Copy config template
COPY docker/config-example.toml /etc/hydrapool/config-example.toml

# Copy Start9 runtime files
COPY start9/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY start9/docker_entrypoint.sh /usr/local/bin/docker_entrypoint.sh
COPY start9/health_check.sh /usr/local/bin/health_check.sh
COPY start9/check-api.sh /usr/local/bin/check-api.sh
COPY start9/check-stratum.sh /usr/local/bin/check-stratum.sh

RUN chmod +x /usr/local/bin/docker_entrypoint.sh \
    /usr/local/bin/health_check.sh \
    /usr/local/bin/check-api.sh \
    /usr/local/bin/check-stratum.sh

# Create data directories
RUN mkdir -p /data/hydrapool /data/prometheus/data /data/grafana \
    /data/logs /data/start9 && \
    chown -R hydrapool:hydrapool /data/hydrapool /data/logs && \
    chown -R nobody:nogroup /data/prometheus && \
    chown -R 472:0 /data/grafana

# Expose ports: Stratum, API, Prometheus, Grafana
EXPOSE 3333 46884 9090 3000

ENTRYPOINT ["tini", "--", "docker_entrypoint.sh"]
