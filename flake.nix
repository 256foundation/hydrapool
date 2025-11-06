# Simple flake.nix for testing
{
  description = "Hydra-Pool development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ (import rust-overlay) ];
        };

        # Simple Rust toolchain
        rustToolchain = pkgs.rust-bin.stable."1.88.0".default.override {
          extensions = [ "rust-src" "rustfmt" "clippy" ];
        };

      in {
        # Development shell
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            rustToolchain
            pkg-config
            clang
            cmake
            git
            openssl
            zeromq
            zstd
            snappy
            bzip2
            lz4
            docker
            docker-buildx
            jq
            imagemagick
            nodejs
            yarn
            # LLVM libraries for Rust compilation
            llvmPackages.libclang
            llvmPackages.llvm
            llvmPackages.bintools
          ];

          shellHook = ''
            # Set environment variables for Rust compilation
            export LIBCLANG_PATH="${pkgs.llvmPackages.libclang.lib}/lib"
            export LLVM_CONFIG_PATH="${pkgs.llvmPackages.llvm}/bin/llvm-config"
            export CC="clang"
            export CXX="clang++"
            
            # Add LLVM libraries to LD_LIBRARY_PATH
            export LD_LIBRARY_PATH="${pkgs.llvmPackages.libclang.lib}/lib:${pkgs.llvmPackages.llvm.lib}:$LD_LIBRARY_PATH"
            
            # Rust-specific environment
            export RUST_LOG=debug
            export PKG_VERSION="1.1.18"
            export BINDGEN_EXTRA_CLANG_ARGS="-I${pkgs.llvmPackages.libclang.dev}/include"

            # Add cargo bin to PATH
            export PATH="$HOME/.cargo/bin:$PATH"

            echo "🚀 Hydra-Pool Development Environment"
            echo "====================================="
            echo "Rust version: $(rustc --version)"
            echo "Cargo version: $(cargo --version)"
            echo "LLVM version: $(clang --version | head -n1)"
            echo ""
            echo "Environment:"
            echo "  LIBCLANG_PATH: $LIBCLANG_PATH"
            echo "  LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
            echo ""
            echo "Available commands:"
            echo "  cargo build --release    - Build Hydra-Pool"
            echo "  cargo test               - Run tests"
            echo "  cargo clippy             - Run linter"
            echo ""
          '';
        };
      });
}