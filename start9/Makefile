PKG_VERSION := $(shell yq e ".version" manifest.yaml)
PKG_ID := $(shell yq e ".id" manifest.yaml)
TS_FILES := $(shell find scripts -name '*.ts' 2>/dev/null)

.DELETE_ON_ERROR:

all: verify

clean:
	rm -f $(PKG_ID).s9pk
	rm -rf docker-images
	rm -f scripts/embassy.js

verify: $(PKG_ID).s9pk
	start-sdk verify s9pk $(PKG_ID).s9pk

# Pack the s9pk archive
$(PKG_ID).s9pk: manifest.yaml instructions.md icon.png scripts/embassy.js docker-images/aarch64.tar docker-images/x86_64.tar assets/compat/config_spec.yaml
	start-sdk pack

# Bundle TypeScript procedures
scripts/embassy.js: $(TS_FILES) deps.ts
	cd scripts && deno run --allow-read --allow-write --allow-net --allow-env bundle.ts

# Build Docker images for both architectures
docker-images/aarch64.tar: Dockerfile ../src/**/* ../Cargo.toml ../Cargo.lock
	mkdir -p docker-images
	docker buildx build \
		--tag start9/$(PKG_ID)/main:$(PKG_VERSION) \
		--platform linux/arm64 \
		-o type=docker,dest=docker-images/aarch64.tar \
		-f Dockerfile ..

docker-images/x86_64.tar: Dockerfile ../src/**/* ../Cargo.toml ../Cargo.lock
	mkdir -p docker-images
	docker buildx build \
		--tag start9/$(PKG_ID)/main:$(PKG_VERSION) \
		--platform linux/amd64 \
		-o type=docker,dest=docker-images/x86_64.tar \
		-f Dockerfile ..

# Install on a running StartOS instance
install: $(PKG_ID).s9pk
	start-cli package install $(PKG_ID).s9pk

.PHONY: all clean verify install
