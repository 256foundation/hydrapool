#!/bin/bash
# Health check dispatcher for Start9.
# Called with a single argument matching the health-check name in manifest.yaml.
# Exit codes: 0 = healthy, 60 = starting, 1 = unhealthy

CHECK_NAME="${1:-}"

case "$CHECK_NAME" in
    api)
        exec /usr/local/bin/check-api.sh
        ;;
    stratum)
        exec /usr/local/bin/check-stratum.sh
        ;;
    *)
        echo "Unknown health check: $CHECK_NAME" >&2
        exit 1
        ;;
esac
