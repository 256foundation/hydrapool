#!/bin/bash

# Mock start-sdk command for testing
# This creates a basic s9pk package structure

case "$1" in
    "pack")
        VERSION="$2"
        echo "Mock start-sdk pack $VERSION"
        echo "Creating s9pk package structure..."
        
        # Create a simple s9pk file (tar.gz with basic structure)
        tar -czf hydrapool-${VERSION}.s9pk \
            manifest.yaml \
            instructions.md \
            icon.png \
            image.tar \
            assets/ \
            *.sh \
            supervisord.conf \
            Dockerfile 2>/dev/null || echo "Some files not found, continuing..."
        
        if [ -f "hydrapool-${VERSION}.s9pk" ]; then
            echo "✓ Created hydrapool-${VERSION}.s9pk"
            ls -la hydrapool-${VERSION}.s9pk
        else
            echo "✗ Failed to create package"
            exit 1
        fi
        ;;
    "verify")
        echo "Mock start-sdk verify"
        echo "✓ Package verification (mock)"
        ;;
    "install")
        echo "Mock start-sdk install"
        echo "✓ Package installation (mock)"
        ;;
    "--version")
        echo "start-sdk version 0.4.0-mock"
        ;;
    "init")
        echo "Mock start-sdk init"
        echo "✓ SDK initialized (mock)"
        ;;
    *)
        echo "Mock start-sdk - unknown command: $1"
        echo "Available commands: pack, verify, install, --version, init"
        exit 1
        ;;
esac