#!/bin/bash
# Health check for the Hydra-Pool API.
# Exit codes: 0 = healthy, 60 = starting, 1 = unhealthy

AUTH_FILE="/data/hydrapool/auth_credentials"

# If auth file doesn't exist yet, service is still starting
if [ ! -f "$AUTH_FILE" ]; then
    echo "Service is starting (no auth credentials yet)"
    exit 60
fi

API_USER=$(sed -n '1p' "$AUTH_FILE")
API_PASS=$(sed -n '2p' "$AUTH_FILE")

# Try the health endpoint
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    --max-time 5 \
    -u "${API_USER}:${API_PASS}" \
    "http://localhost:46884/health" 2>/dev/null)

case "$HTTP_CODE" in
    200)
        echo "API is healthy"
        exit 0
        ;;
    000)
        echo "API is not responding (starting)"
        exit 60
        ;;
    *)
        echo "API returned HTTP $HTTP_CODE"
        exit 1
        ;;
esac
