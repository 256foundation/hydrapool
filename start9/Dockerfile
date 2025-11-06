# Multi-stage Dockerfile for Start9 Hydra-Pool Package
# Combines hydrapool, prometheus, and grafana into a single container

# Stage 1: Build Hydra-Pool
FROM rust:1.88-slim-bullseye AS hydrapool-builder

# Install build dependencies
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

# Stage 2: Final Runtime Image
FROM debian:bullseye-slim

# Install runtime dependencies for all services
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
    && rm -rf /var/lib/apt/lists/*

# Create hydrapool user
RUN groupadd --system hydrapool && \
    useradd --system --gid hydrapool --home-dir /var/lib/hydrapool \
    --no-create-home --shell /usr/sbin/nologin hydrapool

# Create directories
RUN mkdir -p /var/lib/hydrapool /var/log/hydrapool /etc/hydrapool \
    /etc/supervisor/conf.d /var/lib/prometheus /var/lib/grafana \
    /etc/grafana/provisioning/datasources /etc/grafana/provisioning/dashboards /etc/grafana/dashboards && \
    chown -R hydrapool:hydrapool /var/lib/hydrapool /var/log/hydrapool /var/lib/prometheus /var/lib/grafana

# Copy Hydra-Pool binaries
COPY --from=hydrapool-builder /hydrapool/target/release/hydrapool /usr/local/bin/
COPY --from=hydrapool-builder /hydrapool/target/release/hydrapool_cli /usr/local/bin/

# Copy Prometheus binary (using official image as reference)
COPY --from=prom/prometheus:latest /bin/prometheus /usr/local/bin/
COPY --from=prom/prometheus:latest /etc/prometheus /etc/prometheus/

# Copy Grafana files
COPY --from=grafana/grafana:12.2.0 /usr/share/grafana /usr/share/grafana
COPY --from=grafana/grafana:12.2.0 /bin/grafana-server /usr/local/bin/
COPY --from=grafana/grafana:12.2.0 /bin/grafana-cli /usr/local/bin/

# Copy configuration files
COPY docker/config-example.toml /etc/hydrapool/config.toml.template
COPY prometheus/prometheus.yml /etc/prometheus/prometheus.yml.template
COPY prometheus/grafana/provisioning/datasources/prometheus.yml /etc/grafana/provisioning/datasources/
COPY prometheus/grafana/provisioning/dashboards/dashboards.yml /etc/grafana/provisioning/dashboards/
COPY prometheus/grafana/dashboards/ /etc/grafana/dashboards/

# Copy supervisor configuration
COPY start9/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Copy entrypoint script
COPY start9/docker_entrypoint.sh /usr/local/bin/docker_entrypoint.sh
COPY start9/health_check.sh /usr/local/bin/health_check.sh

# Set permissions
RUN chmod +x /usr/local/bin/hydrapool /usr/local/bin/hydrapool_cli \
    /usr/local/bin/prometheus /usr/local/bin/grafana-server \
    /usr/local/bin/docker_entrypoint.sh /usr/local/bin/health_check.sh && \
    chown hydrapool:hydrapool /etc/hydrapool/config.toml.template

# Expose ports
EXPOSE 3333 46884 9090 3000

# Set environment
ENV RUST_LOG=info

# Use supervisor to manage all services
ENTRYPOINT ["/usr/local/bin/docker_entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]