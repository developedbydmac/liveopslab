#!/bin/bash

# LiveOps Lab Chaos Engineering Script
# This script injects controlled failures into the sample application

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_CONTAINER="liveops-sample-app"
CHAOS_DURATION=${CHAOS_DURATION:-90}  # Default 90 seconds

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

check_dependencies() {
    log "Checking dependencies..."
    
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed or not in PATH"
    fi
    
    if ! docker ps | grep -q "$APP_CONTAINER"; then
        error "Sample application container '$APP_CONTAINER' is not running"
    fi
    
    log "Dependencies check passed"
}

inject_http_errors() {
    log "🔥 Injecting HTTP 500 errors for ${CHAOS_DURATION} seconds..."
    
    # Set chaos mode environment variable
    docker exec "$APP_CONTAINER" sh -c 'export CHAOS_MODE=true'
    
    # Alternative: restart container with chaos mode
    docker exec "$APP_CONTAINER" sh -c 'kill -USR1 1' || true
    
    log "HTTP errors injection started. Monitoring for ${CHAOS_DURATION} seconds..."
    
    # Monitor error rate
    for i in $(seq 1 $((CHAOS_DURATION/10))); do
        sleep 10
        log "Chaos experiment running... ${i}0/${CHAOS_DURATION} seconds"
        
        # Test the chaos endpoint
        if curl -s http://localhost:8000/api/chaos | grep -q "error"; then
            log "✅ Chaos mode confirmed - errors being generated"
        fi
    done
    
    # Restore normal operation
    docker exec "$APP_CONTAINER" sh -c 'unset CHAOS_MODE' || true
    log "🔧 Restored normal operation"
}

inject_latency() {
    log "🐌 Injecting high latency for ${CHAOS_DURATION} seconds..."
    
    # Use tc (traffic control) to add network delay
    docker exec "$APP_CONTAINER" sh -c '
        apt-get update -qq && apt-get install -y iproute2 > /dev/null 2>&1 || true
        tc qdisc add dev eth0 root netem delay 2000ms 500ms
    ' || warn "Could not inject network latency (tc not available)"
    
    log "Latency injection started. Monitoring for ${CHAOS_DURATION} seconds..."
    
    sleep "$CHAOS_DURATION"
    
    # Remove latency
    docker exec "$APP_CONTAINER" sh -c 'tc qdisc del dev eth0 root' || true
    log "🔧 Removed latency injection"
}

inject_cpu_spike() {
    log "💻 Injecting CPU spike for ${CHAOS_DURATION} seconds..."
    
    # Start CPU stress in background
    docker exec -d "$APP_CONTAINER" sh -c '
        # Simple CPU stress using dd and /dev/urandom
        timeout '"$CHAOS_DURATION"' dd if=/dev/urandom of=/dev/null bs=1M &
        timeout '"$CHAOS_DURATION"' dd if=/dev/urandom of=/dev/null bs=1M &
        timeout '"$CHAOS_DURATION"' dd if=/dev/urandom of=/dev/null bs=1M &
        timeout '"$CHAOS_DURATION"' dd if=/dev/urandom of=/dev/null bs=1M &
        wait
    ' || warn "Could not inject CPU stress"
    
    log "CPU spike injection started. Monitoring for ${CHAOS_DURATION} seconds..."
    
    # Monitor CPU usage
    for i in $(seq 1 $((CHAOS_DURATION/10))); do
        sleep 10
        cpu_usage=$(docker exec "$APP_CONTAINER" sh -c 'top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk "{print 100 - \$1}"' || echo "unknown")
        log "CPU usage: ${cpu_usage}%"
    done
    
    log "🔧 CPU spike experiment completed"
}

memory_pressure() {
    log "🧠 Creating memory pressure for ${CHAOS_DURATION} seconds..."
    
    # Create memory pressure
    docker exec -d "$APP_CONTAINER" sh -c '
        python3 -c "
import time
import sys

# Allocate memory in 100MB chunks
memory_hog = []
start_time = time.time()
chunk_size = 1024 * 1024 * 100  # 100MB

while time.time() - start_time < '"$CHAOS_DURATION"':
    try:
        memory_hog.append(b\"x\" * chunk_size)
        print(f\"Allocated {len(memory_hog) * 100}MB\")
        time.sleep(5)
    except MemoryError:
        print(\"Memory limit reached\")
        break
    except KeyboardInterrupt:
        break

print(\"Memory pressure test completed\")
"
    ' || warn "Could not create memory pressure"
    
    log "Memory pressure started. Monitoring for ${CHAOS_DURATION} seconds..."
    sleep "$CHAOS_DURATION"
    log "🔧 Memory pressure experiment completed"
}

disk_fill() {
    log "💾 Filling disk space for ${CHAOS_DURATION} seconds..."
    
    # Create temporary large file
    docker exec -d "$APP_CONTAINER" sh -c '
        # Create a 1GB file to consume disk space
        timeout '"$CHAOS_DURATION"' dd if=/dev/zero of=/tmp/disk_fill.tmp bs=1M count=1024 2>/dev/null || true
        sleep '"$CHAOS_DURATION"'
        rm -f /tmp/disk_fill.tmp
    ' || warn "Could not fill disk space"
    
    log "Disk fill started. Will auto-cleanup after ${CHAOS_DURATION} seconds..."
    sleep "$CHAOS_DURATION"
    log "🔧 Disk fill experiment completed"
}

network_partition() {
    log "🌐 Simulating network partition for ${CHAOS_DURATION} seconds..."
    
    # Block traffic to external services (simulate network partition)
    docker exec "$APP_CONTAINER" sh -c '
        # Install iptables if not available
        apt-get update -qq && apt-get install -y iptables > /dev/null 2>&1 || true
        
        # Block outbound traffic (except local)
        iptables -A OUTPUT -d 127.0.0.0/8 -j ACCEPT
        iptables -A OUTPUT -d 172.16.0.0/12 -j ACCEPT
        iptables -A OUTPUT -j DROP
    ' || warn "Could not create network partition"
    
    log "Network partition started. Monitoring for ${CHAOS_DURATION} seconds..."
    sleep "$CHAOS_DURATION"
    
    # Restore network connectivity
    docker exec "$APP_CONTAINER" sh -c 'iptables -F OUTPUT' || true
    log "🔧 Network partition removed"
}

run_all_chaos() {
    log "🎭 Running comprehensive chaos test suite..."
    
    inject_http_errors &
    sleep 30
    inject_latency &
    sleep 30
    inject_cpu_spike &
    
    wait
    log "🔧 All chaos experiments completed"
}

show_usage() {
    cat << EOF
LiveOps Lab Chaos Engineering Script

Usage: $0 [OPTIONS] <experiment>

Experiments:
  errors      Inject HTTP 500 errors
  latency     Add network latency
  cpu         Create CPU spike
  memory      Create memory pressure
  disk        Fill disk space
  network     Simulate network partition
  all         Run all experiments sequentially

Options:
  -d, --duration SECONDS   Duration of chaos experiment (default: 90)
  -h, --help              Show this help message

Examples:
  $0 errors                    # Inject errors for 90 seconds
  $0 --duration 60 cpu         # CPU spike for 60 seconds
  $0 all                       # Run all experiments

Monitoring:
  - Check Grafana: http://localhost:3000
  - Check Prometheus: http://localhost:9090
  - Check Alerts: http://localhost:9093
EOF
}

main() {
    local experiment=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--duration)
                CHAOS_DURATION="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            errors|latency|cpu|memory|disk|network|all)
                experiment="$1"
                shift
                ;;
            *)
                error "Unknown option: $1. Use --help for usage information."
                ;;
        esac
    done
    
    if [[ -z "$experiment" ]]; then
        error "No experiment specified. Use --help for usage information."
    fi
    
    log "Starting LiveOps Lab Chaos Engineering"
    log "Experiment: $experiment"
    log "Duration: ${CHAOS_DURATION} seconds"
    
    check_dependencies
    
    case $experiment in
        errors)
            inject_http_errors
            ;;
        latency)
            inject_latency
            ;;
        cpu)
            inject_cpu_spike
            ;;
        memory)
            memory_pressure
            ;;
        disk)
            disk_fill
            ;;
        network)
            network_partition
            ;;
        all)
            run_all_chaos
            ;;
        *)
            error "Unknown experiment: $experiment"
            ;;
    esac
    
    log "🎉 Chaos experiment completed successfully!"
    log "📊 Check your monitoring dashboards for impact analysis"
    log "📋 Review alerts and system behavior during the experiment"
}

# Run main function with all arguments
main "$@"
