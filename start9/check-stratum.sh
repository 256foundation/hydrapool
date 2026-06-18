#!/bin/bash
# Health check for the Stratum mining port.
# Exit codes: 0 = healthy, 60 = starting, 1 = unhealthy

if nc -z localhost 3333 2>/dev/null; then
    echo "Stratum server is accepting connections"
    exit 0
else
    # Check if supervisord is even running hydrapool yet
    if pgrep -f "hydrapool --config" > /dev/null 2>&1; then
        echo "Stratum port not open yet (starting)"
        exit 60
    else
        echo "Hydra-Pool process not running"
        exit 1
    fi
fi
