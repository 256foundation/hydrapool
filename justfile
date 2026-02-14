# Set default log level if not provided through environment
export LOG_LEVEL := env_var_or_default("RUST_LOG", "info")

default : build

build:
	@echo "Building Hydra-Pool..."
	cargo build

build-release:
	@echo "Building Hydra-Pool in release mode..."
	cargo build --release

# For log level use RUST_LOG=<<level>> just run
run config="config.toml":
	RUST_LOG={{LOG_LEVEL}} cargo run -- --config={{config}}

check:
	cargo check

# Build the Start9 .s9pk package
start9:
	@echo "Building Start9 package..."
	cd start9 && make
