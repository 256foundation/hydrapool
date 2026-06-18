# Set default log level if not provided through environment
export LOG_LEVEL := env_var_or_default("RUST_LOG", "info")

default : build

build:
	@echo "Building Hydrapool..."
	cargo build

build-release:
	@echo "Building Hydrapool in release mode..."
	cargo build --release

build-profile:
	@echo "Building Hydrapool release with debug symbols..."
	cargo build --profile release-with-debug

# Run under perf and generate flamegraph SVG
# Requires: perf (linux-tools), inferno (cargo install inferno)
# Uses frame pointer unwinding for reliable stacks in async/tokio code
profile config="config.toml": build-profile
	@echo "Recording perf data... Stop hydrapool with Ctrl+C when done."
	sudo perf record -g --call-graph fp -F 99 -o perf.data \
		./target/release-with-debug/hydrapool --config={{config}}
	@echo "Generating flamegraph..."
	sudo perf script -i perf.data | inferno-collapse-perf | inferno-flamegraph > flamegraph.svg
	@echo "Flamegraph written to flamegraph.svg"

# For log level use RUST_LOG=<<level>> just run
run config="config.toml":
	RUST_LOG={{LOG_LEVEL}} cargo run -- --config={{config}}

check:
	cargo check

# Build the Start9 .s9pk package
start9:
	@echo "Building Start9 package..."
	cd start9 && make
