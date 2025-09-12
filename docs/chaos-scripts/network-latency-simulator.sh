#!/bin/bash
# LiveOpsLab Chaos Engineering - Network Latency Simulator
# Simulates high latency and packet loss for ticket scanning delays

set -e

# Configuration
SCRIPT_NAME="Network Latency Simulator"
LOG_FILE="/var/log/chaos-engineering.log"
INTERFACE="eth0"
LATENCY_MS=500          # Base latency in milliseconds
JITTER_MS=100           # Jitter variation
PACKET_LOSS=5           # Packet loss percentage
DURATION_MINUTES=5      # Duration of latency simulation
TARGET_PORTS="80,443,8080"  # Ports to affect

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log_event() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Function to check if tc (traffic control) is available
check_tc_available() {
    if ! command -v tc &> /dev/null; then
        log_event "ERROR" "tc (traffic control) command not found. Install iproute2 package."
        exit 1
    fi
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_event "ERROR" "This script must be run as root to modify network traffic control"
        exit 1
    fi
}

# Function to get current network statistics
get_network_stats() {
    local interface=$1
    local stats_file="/proc/net/dev"
    
    if [ -f "$stats_file" ]; then
        grep "$interface:" "$stats_file" | awk '{print "RX_bytes:" $2 " TX_bytes:" $10 " RX_packets:" $3 " TX_packets:" $11}'
    else
        echo "Stats unavailable"
    fi
}

# Function to measure current latency
measure_latency() {
    local target=${1:-8.8.8.8}
    local count=${2:-3}
    
    if command -v ping &> /dev/null; then
        ping -c "$count" "$target" 2>/dev/null | tail -1 | awk -F'/' '{print $5}' | head -1
    else
        echo "0"
    fi
}

# Function to clean up existing traffic control rules
cleanup_tc_rules() {
    local interface=$1
    
    log_event "INFO" "Cleaning up existing traffic control rules on $interface"
    
    # Remove any existing qdisc
    tc qdisc del dev "$interface" root 2>/dev/null || true
    tc qdisc del dev "$interface" ingress 2>/dev/null || true
    
    log_event "SUCCESS" "Traffic control rules cleaned up"
}

# Function to simulate network latency and packet loss
simulate_network_degradation() {
    local interface=$1
    local latency_ms=$2
    local jitter_ms=$3
    local packet_loss=$4
    local duration_minutes=$5
    
    log_event "INFO" "Starting network degradation simulation"
    log_event "INFO" "Interface: $interface, Latency: ${latency_ms}ms±${jitter_ms}ms, Loss: ${packet_loss}%, Duration: ${duration_minutes}min"
    
    # Get baseline measurements
    local baseline_latency=$(measure_latency)
    local baseline_stats=$(get_network_stats "$interface")
    
    log_event "INFO" "Baseline latency: ${baseline_latency}ms"
    log_event "INFO" "Baseline stats: $baseline_stats"
    
    # Apply traffic control rules
    log_event "INFO" "Applying network degradation rules..."
    
    # Create root qdisc with handle 1:
    if tc qdisc add dev "$interface" root handle 1: htb default 12; then
        log_event "SUCCESS" "Root qdisc created"
    else
        log_event "ERROR" "Failed to create root qdisc"
        return 1
    fi
    
    # Create class with rate limiting
    if tc class add dev "$interface" parent 1: classid 1:12 htb rate 100mbit ceil 100mbit; then
        log_event "SUCCESS" "Traffic class created"
    else
        log_event "ERROR" "Failed to create traffic class"
        cleanup_tc_rules "$interface"
        return 1
    fi
    
    # Apply netem (network emulation) for latency and packet loss
    local netem_params="delay ${latency_ms}ms ${jitter_ms}ms"
    if [ "$packet_loss" -gt 0 ]; then
        netem_params="$netem_params loss ${packet_loss}%"
    fi
    
    if tc qdisc add dev "$interface" parent 1:12 handle 20: netem $netem_params; then
        log_event "SUCCESS" "Network emulation rules applied: $netem_params"
    else
        log_event "ERROR" "Failed to apply network emulation rules"
        cleanup_tc_rules "$interface"
        return 1
    fi
    
    # Send monitoring notification
    send_notification "LATENCY_START" "Network degradation simulation started - ${latency_ms}ms latency, ${packet_loss}% loss"
    
    # Monitor during degradation period
    local start_time=$(date +%s)
    log_event "INFO" "Monitoring network performance during degradation..."
    
    # Create performance monitoring log
    local perf_log="/tmp/network-performance-$(date +%s).log"
    echo "timestamp,latency_ms,rx_bytes,tx_bytes,rx_packets,tx_packets" > "$perf_log"
    
    for ((i=1; i<=duration_minutes; i++)); do
        local current_latency=$(measure_latency)
        local current_stats=$(get_network_stats "$interface")
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        
        log_event "INFO" "Degradation minute $i/$duration_minutes - Latency: ${current_latency}ms"
        
        # Log performance data
        echo "$timestamp,$current_latency,$current_stats" >> "$perf_log"
        
        # Simulate ticket scanning issues
        if [ $i -eq 2 ]; then
            log_event "WARNING" "Simulating ticket scanning delays due to network latency"
            send_notification "TICKET_SCAN_DELAY" "Ticket scanning experiencing delays due to network issues"
        fi
        
        # Alert if latency is extreme
        if [ "${current_latency%.*}" -gt $((latency_ms * 2)) ]; then
            log_event "CRITICAL" "Extreme latency detected: ${current_latency}ms"
        fi
        
        sleep 60
    done
    
    # Cleanup traffic control rules
    log_event "INFO" "Removing network degradation rules..."
    cleanup_tc_rules "$interface"
    
    # Wait for network to stabilize
    log_event "INFO" "Waiting for network to stabilize..."
    sleep 30
    
    # Get final measurements
    local final_latency=$(measure_latency)
    local final_stats=$(get_network_stats "$interface")
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    log_event "INFO" "Final latency: ${final_latency}ms"
    log_event "INFO" "Final stats: $final_stats"
    log_event "INFO" "Total test duration: ${total_duration} seconds"
    
    # Send recovery notification
    send_notification "LATENCY_RECOVERY" "Network degradation simulation completed - Performance restored"
    
    # Generate performance report
    cat >> "$LOG_FILE" << EOF

=== NETWORK LATENCY SIMULATION SUMMARY ===
Start Time: $(date -d "@$start_time" '+%Y-%m-%d %H:%M:%S')
End Time: $(date -d "@$end_time" '+%Y-%m-%d %H:%M:%S')
Duration: ${total_duration} seconds (${duration_minutes} minutes planned)
Interface: $interface
Applied Latency: ${latency_ms}ms ± ${jitter_ms}ms
Applied Packet Loss: ${packet_loss}%
Baseline Latency: ${baseline_latency}ms
Final Latency: ${final_latency}ms
Performance Log: $perf_log

EOF
    
    log_event "SUCCESS" "Performance data saved to $perf_log"
    return 0
}

# Function to send notification to monitoring systems
send_notification() {
    local event_type=$1
    local message=$2
    
    # Send to CloudWatch if AWS CLI is available
    if command -v aws &> /dev/null; then
        aws cloudwatch put-metric-data \
            --namespace "LiveOpsLab/ChaosEngineering" \
            --metric-data MetricName="NetworkLatencyEvent",Value=1,Unit=Count \
            --region "${AWS_REGION:-us-east-1}" &>/dev/null || true
    fi
    
    # Log to syslog
    logger -t "chaos-engineering" "$event_type: $message"
    
    # Send to Prometheus if available
    if command -v curl &> /dev/null && [ -n "$PROMETHEUS_PUSHGATEWAY" ]; then
        curl -X POST "$PROMETHEUS_PUSHGATEWAY/metrics/job/chaos-engineering/instance/$(hostname)" \
             --data-binary "network_latency_event{type=\"$event_type\"} 1" &>/dev/null || true
    fi
}

# Function to run pre-flight checks
pre_flight_checks() {
    log_event "INFO" "Running pre-flight checks..."
    
    # Check if interface exists
    if ! ip link show "$INTERFACE" &>/dev/null; then
        log_event "ERROR" "Network interface $INTERFACE not found"
        exit 1
    fi
    
    # Check if interface is up
    if ! ip link show "$INTERFACE" | grep -q "state UP"; then
        log_event "ERROR" "Network interface $INTERFACE is not up"
        exit 1
    fi
    
    # Check for existing tc rules
    if tc qdisc show dev "$INTERFACE" | grep -q "netem\|tbf\|htb"; then
        log_event "WARNING" "Existing traffic control rules detected on $INTERFACE"
        read -p "Clean up existing rules? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cleanup_tc_rules "$INTERFACE"
        else
            log_event "INFO" "Latency simulation cancelled - existing rules present"
            exit 0
        fi
    fi
    
    log_event "SUCCESS" "Pre-flight checks completed"
}

# Function to display usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

LiveOpsLab Network Latency/Degradation Simulation Script

Options:
    -i, --interface INTERFACE    Network interface to affect (default: eth0)
    -l, --latency MS            Base latency in milliseconds (default: 500)
    -j, --jitter MS             Jitter variation in milliseconds (default: 100)
    -p, --packet-loss PERCENT   Packet loss percentage (default: 5)
    -t, --time MINUTES          Duration in minutes (default: 5)
    -f, --log-file FILE         Log file path (default: /var/log/chaos-engineering.log)
    -n, --no-confirm            Skip confirmation prompt
    -d, --dry-run               Show what would be done without executing
    -c, --cleanup               Clean up existing traffic control rules and exit
    -h, --help                  Show this help message

Examples:
    $0                          # Use default settings (500ms±100ms, 5% loss, 5min)
    $0 -l 200 -j 50 -p 10       # Lower latency with higher packet loss
    $0 -t 10 --no-confirm       # 10-minute test without confirmation
    $0 --cleanup                # Clean up existing rules only
    $0 --dry-run                # Preview the operation

Environment Variables:
    AWS_REGION                  AWS region for CloudWatch metrics
    PROMETHEUS_PUSHGATEWAY      Prometheus pushgateway URL for metrics

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--interface)
            INTERFACE="$2"
            shift 2
            ;;
        -l|--latency)
            LATENCY_MS="$2"
            shift 2
            ;;
        -j|--jitter)
            JITTER_MS="$2"
            shift 2
            ;;
        -p|--packet-loss)
            PACKET_LOSS="$2"
            shift 2
            ;;
        -t|--time)
            DURATION_MINUTES="$2"
            shift 2
            ;;
        -f|--log-file)
            LOG_FILE="$2"
            shift 2
            ;;
        -n|--no-confirm)
            NO_CONFIRM=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -c|--cleanup)
            CLEANUP_ONLY=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    echo -e "${BLUE}=== LiveOpsLab Chaos Engineering - Network Latency Simulator ===${NC}"
    echo
    
    # Check requirements
    check_root
    check_tc_available
    
    # Create log file if it doesn't exist
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    
    # Handle cleanup-only mode
    if [ "$CLEANUP_ONLY" = true ]; then
        log_event "INFO" "Cleanup mode - removing existing traffic control rules"
        cleanup_tc_rules "$INTERFACE"
        echo -e "${GREEN}✅ Traffic control rules cleaned up${NC}"
        exit 0
    fi
    
    # Handle dry run
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}DRY RUN MODE - No actual changes will be made${NC}"
        echo "Would affect interface: $INTERFACE"
        echo "Would apply latency: ${LATENCY_MS}ms ± ${JITTER_MS}ms"
        echo "Would apply packet loss: ${PACKET_LOSS}%"
        echo "Would run for: $DURATION_MINUTES minutes"
        echo "Would log to: $LOG_FILE"
        exit 0
    fi
    
    # Pre-flight checks
    pre_flight_checks
    
    # Confirmation prompt
    if [ "$NO_CONFIRM" != true ]; then
        echo -e "${YELLOW}WARNING: This will introduce network latency and packet loss${NC}"
        echo "Interface: $INTERFACE"
        echo "Latency: ${LATENCY_MS}ms ± ${JITTER_MS}ms"
        echo "Packet Loss: ${PACKET_LOSS}%"
        echo "Duration: $DURATION_MINUTES minutes"
        echo
        echo "This will affect ticket scanning, API responses, and user experience."
        echo
        read -p "Are you sure you want to continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_event "INFO" "Network latency simulation cancelled by user"
            exit 0
        fi
    fi
    
    # Record test start
    log_event "INFO" "=== Starting Network Latency Chaos Test ==="
    log_event "INFO" "Target interface: $INTERFACE"
    log_event "INFO" "Latency: ${LATENCY_MS}ms ± ${JITTER_MS}ms"
    log_event "INFO" "Packet loss: ${PACKET_LOSS}%"
    log_event "INFO" "Duration: $DURATION_MINUTES minutes"
    log_event "INFO" "Executed by: $(whoami)"
    log_event "INFO" "System: $(hostname) ($(uname -r))"
    
    # Execute the simulation
    if simulate_network_degradation "$INTERFACE" "$LATENCY_MS" "$JITTER_MS" "$PACKET_LOSS" "$DURATION_MINUTES"; then
        log_event "SUCCESS" "Network latency simulation completed successfully"
        echo -e "${GREEN}✅ Network latency simulation completed successfully${NC}"
    else
        log_event "ERROR" "Network latency simulation failed"
        echo -e "${RED}❌ Network latency simulation failed${NC}"
        
        # Ensure cleanup on failure
        cleanup_tc_rules "$INTERFACE"
        exit 1
    fi
    
    log_event "INFO" "=== Network Latency Chaos Test Complete ==="
}

# Trap signals for cleanup
trap 'log_event "WARNING" "Network latency simulation interrupted - cleaning up"; cleanup_tc_rules "$INTERFACE"; exit 130' INT TERM

# Execute main function
main "$@"
