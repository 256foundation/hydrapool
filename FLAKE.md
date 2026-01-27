# Nix Flake for Hydra-Pool

This flake provides a complete Nix-based build system for Hydra-Pool, including the main application, Start9 package building, Docker images, and NixOS module.

## Structure

```
flake.nix              # Main flake definition
nixos-module.nix       # NixOS service module
default.nix            # Legacy compatibility (optional)
```

## Usage

### Development Environment

```bash
# Enter development shell
nix develop

# Build Hydra-Pool
cargo build --release

# Run tests
cargo test

# Build Start9 package
make -C start9 build
make -C start9 pack
```

### Building Packages

```bash
# Build Hydra-Pool package
nix build .#hydrapool

# Build Start9 package
nix build .#start9

# Build Docker image
nix build .#docker

# Build all packages
nix build .#
```

### Running Applications

```bash
# Build Hydra-Pool
nix run .#build

# Run tests
nix run .#test

# Build Start9 package
nix run .#package
```

### NixOS Module

Add to your NixOS configuration:

```nix
{
  inputs.hydrapool.url = "github:256-Foundation/Hydra-Pool";

  outputs = { self, nixpkgs, hydrapool }: {
    nixosConfigurations.my-server = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        hydrapool.nixosModules.default
      ];
    };
  };
}
```

Then configure Hydra-Pool in your `configuration.nix`:

```nix
{
  services.hydrapool = {
    enable = true;
    bootstrapAddress = "your-bitcoin-address";
    bitcoin = {
      network = "signet";
      rpcUrl = "http://localhost:38332";
      rpcUser = "your-rpc-user";
      rpcPassword = "your-rpc-password";
    };
    openFirewall = true;
  };
}
```

## Features

### 🦀 Rust Package Building

- Uses Crane for reproducible Rust builds
- Exact Rust version pinning (1.88.0)
- Dependency caching for faster builds
- Cross-compilation support

### 📦 Start9 Package Support

- Complete Start9 package building
- Multi-architecture Docker images
- Automatic dependency management
- Package verification

### 🐳 Docker Integration

- Nix-based Docker image building
- Multi-platform support (AMD64, ARM64)
- Minimal runtime dependencies
- Security hardening

### 🖥️ NixOS Module

- Full service configuration
- Systemd integration
- Firewall management
- Monitoring stack (Prometheus + Grafana)
- User and permission management

## Configuration Options

### Hydra-Pool Service

```nix
services.hydrapool = {
  enable = true;
  
  # Basic settings
  bootstrapAddress = "bc1q...";
  poolFee = 100;  # 1% in basis points
  
  # Bitcoin configuration
  bitcoin = {
    network = "signet";  # main, testnet4, signet
    rpcUrl = "http://bitcoind:8332";
    rpcUser = "user";
    rpcPassword = "password";
  };
  
  # Mining configuration
  stratum = {
    host = "0.0.0.0";
    port = 3333;
    startDifficulty = 1;
  };
  
  # API configuration
  api = {
    host = "0.0.0.0";
    port = 46884;
    authUser = "admin";
    authToken = "your-token";
  };
  
  # Monitoring
  enablePrometheus = true;
  enableGrafana = true;
  grafana = {
    port = 3000;
    adminPassword = "secure-password";
  };
  
  # Security
  openFirewall = true;
};
```

## Development

### Adding Dependencies

1. Update `commonBuildInputs` and `commonRuntimeDeps` in `flake.nix`
2. Update the NixOS module if needed
3. Test with `nix develop`

### Building for Different Platforms

```bash
# AMD64
nix build .#hydrapool --system x86_64-linux

# ARM64
nix build .#hydrapool --system aarch64-linux

# Cross-compilation
nix build .#hydrapool --system x86_64-linux --impure
```

### Testing

```bash
# Run all tests
nix flake check

# Test specific package
nix build .#hydrapool --check

# Test NixOS module
nix eval .#nixosModules.default
```

## Troubleshooting

### Common Issues

1. **Rust Build Failures**: Ensure Rust 1.88.0 is available
2. **Missing Dependencies**: Check `commonBuildInputs` and `commonRuntimeDeps`
3. **Start9 Package Issues**: Verify Docker and Start SDK are installed
4. **NixOS Module**: Check systemd logs with `journalctl -u hydrapool`

### Debug Commands

```bash
# Development shell info
nix develop --print-build-logs

# Package dependencies
nix graph .#hydrapool

# Build details
nix build .#hydrapool --show-trace

# NixOS module options
nix eval .#nixosModules.default --apply 'builtins.attrNames'
```

## Contributing

When contributing to the Nix flake:

1. Test with `nix flake check`
2. Update documentation
3. Ensure all builds succeed
4. Test NixOS module functionality

## Resources

- [Nix Flakes](https://nixos.wiki/wiki/Flakes)
- [Crane](https://github.com/ipetkov/crane)
- [NixOS Modules](https://nixos.org/manual/nixos/stable/#sec-writing-modules)
- [Hydra-Pool Documentation](https://hydrapool.org)
