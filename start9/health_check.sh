#!/bin/bash

# Health check script for Hydra-Pool Start9 package
set -e

# Function to check if a service is responding
check_service() {
    local service_name=$1
    local url=$2
    local expected_status=${3:-200}
    
    echo "Checking $service_name at $url..."
    
    if curl -f -s -o /dev/null -w "%{http_code}" "$url" | grep -q "$expected_status"; then
        echo "✓ $service_name is healthy"
        return 0
    else
        echo "✗ $service_name is unhealthy"
        return 1
    fi
}

# Function to check Hydra-Pool API with auth
check_hydrapool() {
    local api_url="http://localhost:46884/health"
    
    echo "Checking Hydra-Pool API..."
    
    # Try without auth first
    if curl -f -s -o /dev/null -w "%{http_code}" "$api_url" | grep -q "200"; then
        echo "✓ Hydra-Pool API is healthy (no auth)"
        return 0
    fi
    
    # Try with auth if environment variables are set
    if [ -n "$API_USER" ] && [ -n "$API_TOKEN" ]; then
        if curl -f -s -u "$API_USER:$API_TOKEN" -o /dev/null -w "%{http_code}" "$api_url" | grep -q "200"; then
            echo "✓ Hydra-Pool API is healthy (with auth)"
            return 0
        fi
    fi
    
    echo "✗ Hydra-Pool API is unhealthy"
    return 1
}

# Function to check if process is running
check_process() {
    local process_name=$1
    local pid_file=$2
    
    echo "Checking $process_name process..."
    
    if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        echo "✓ $process_name process is running"
        return 0
    else
        echo "✗ $process_name process is not running"
        return 1
    fi
}

# Main health check
echo "Starting Hydra-Pool health checks..."

# Check individual services
exit_code=0

# Check Hydra-Pool API
if ! check_hydrapool; then
    exit_code=1
fi

# Check Prometheus
if ! check_service "Prometheus" "http://localhost:9090/-/healthy"; then
    exit_code=1
fi

# Check Grafana
if ! check_service "Grafana" "http://localhost:3000/api/health"; then
    exit_code=1
fi

# Check Stratum port (simple port check)
echo "Checking Stratum port..."
if nc -z localhost 3333; then
    echo "✓ Stratum port 3333 is open"
else
    echo "✗ Stratum port 3333 is not accessible"
    exit_code=1
fi

# Output overall status
if [ $exit_code -eq 0 ]; then
    echo "All services are healthy"
    exit 0
else
    echo "Some services are unhealthy"
    exit 1
fi