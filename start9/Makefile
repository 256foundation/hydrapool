PKG_ID := hydrapool
PKG_VERSION := 1.1.18
DOCKER_REGISTRY := start9/$(PKG_ID)

.PHONY: build build-release clean pack verify install

# Build the Docker image
build:
	docker build -t $(DOCKER_REGISTRY)/main:$(PKG_VERSION) -f Dockerfile ..

# Build for multiple architectures
build-release:
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--tag $(DOCKER_REGISTRY)/main:$(PKG_VERSION) \
		-f Dockerfile .

# Clean up
clean:
	docker rmi $(DOCKER_REGISTRY)/main:$(PKG_VERSION) || true
	rm -f image.tar

# Create the Start9 package
pack: build
	docker buildx build \
		--tag $(DOCKER_REGISTRY)/main:$(PKG_VERSION) \
		--platform linux/arm64 \
		-f Dockerfile \
		-o type=docker,dest=image.tar ..
	bash start-sdk pack $(PKG_VERSION)
	# Clean up unused image.tar to save space
	rm -f image.tar

# Verify the package
verify: pack
	bash start-sdk verify

# Install locally (for testing)
install: verify
	bash start-sdk install

# Development helpers
dev-build:
	cargo build --release

dev-test:
	cargo test

dev-lint:
	cargo clippy --no-deps
	cargo check

# Generate documentation
docs:
	@echo "Hydra-Pool Start9 Package"
	@echo "========================="
	@echo ""
	@echo "Build commands:"
	@echo "  make build          - Build Docker image"
	@echo "  make build-release  - Build for multiple architectures"
	@echo "  make pack           - Create Start9 package"
	@echo "  make verify         - Verify package integrity"
	@echo "  make install        - Install package locally"
	@echo ""
	@echo "Development commands:"
	@echo "  make dev-build      - Build Rust binaries"
	@echo "  make dev-test       - Run tests"
	@echo "  make dev-lint       - Run linting"
	@echo ""
	@echo "Clean up:"
	@echo "  make clean          - Remove Docker images and artifacts"