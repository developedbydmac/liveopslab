#!/bin/bash
# LiveOpsLab Chaos Engineering - AP Failure Simulation
# Simulates Access Point failure by disabling network interface

set -e

# Configuration
SCRIPT_NAME="AP Failure Simulator"
LOG_FILE="/var/log/chaos-engineering.log"
INTERFACE="eth0"  # Primary network interface
DOWNTIME_MINUTES=3
MAX_RETRIES=3

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log_event() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_event "ERROR" "This script must be run as root to modify network interfaces"
        exit 1
    fi
}

# Function to get network interface status
get_interface_status() {
    local interface=$1
    if ip link show "$interface" &>/dev/null; then
        ip link show "$interface" | grep -q "state UP" && echo "UP" || echo "DOWN"
    else
        echo "NOT_FOUND"
    fi
}

# Function to get current connections
get_connection_count() {
    netstat -an | grep :80 | grep ESTABLISHED | wc -l
}

# Function to send notification to monitoring systems
send_notification() {
    local event_type=$1
    local message=$2
    
    # Send to CloudWatch if AWS CLI is available
    if command -v aws &> /dev/null; then
        aws cloudwatch put-metric-data \
            --namespace "LiveOpsLab/ChaosEngineering" \
            --metric-data MetricName="APFailureEvent",Value=1,Unit=Count \
            --region "${AWS_REGION:-us-east-1}" &>/dev/null || true
    fi
    
    # Log to syslog
    logger -t "chaos-engineering" "$event_type: $message"
    
    # Send to Prometheus pushgateway if available
    if command -v curl &> /dev/null && [ -n "$PROMETHEUS_PUSHGATEWAY" ]; then
        curl -X POST "$PROMETHEUS_PUSHGATEWAY/metrics/job/chaos-engineering/instance/$(hostname)" \
             --data-binary "ap_failure_event{type=\"$event_type\"} 1" &>/dev/null || true
    fi
}

# Function to simulate AP failure
simulate_ap_failure() {
    local interface=$1
    local downtime_minutes=$2
    
    log_event "INFO" "Starting AP failure simulation on interface $interface"
    log_event "INFO" "Planned downtime: $downtime_minutes minutes"
    
    # Get baseline metrics
    local initial_connections=$(get_connection_count)
    local initial_status=$(get_interface_status "$interface")
    
    log_event "INFO" "Pre-failure status - Interface: $initial_status, Active connections: $initial_connections"
    
    # Record failure start time
    local failure_start=$(date +%s)
    send_notification "FAILURE_START" "AP failure simulation started on $interface"
    
    # Disable the network interface
    log_event "WARNING" "Disabling network interface $interface"
    if ip link set "$interface" down; then
        log_event "SUCCESS" "Network interface $interface disabled successfully"
    else
        log_event "ERROR" "Failed to disable network interface $interface"
        return 1
    fi
    
    # Monitor during downtime
    log_event "INFO" "Monitoring system during ${downtime_minutes}-minute outage..."
    
    for ((i=1; i<=downtime_minutes; i++)); do
        sleep 60
        local current_status=$(get_interface_status "$interface")
        local current_connections=$(get_connection_count)
        
        log_event "INFO" "Downtime minute $i/$downtime_minutes - Interface: $current_status, Connections: $current_connections"
        
        # Simulate monitoring alerts
        if [ $i -eq 1 ]; then
            send_notification "MONITORING_ALERT" "Network interface down - Service unavailable"
        fi
        
        # Log connection drops
        if [ "$current_connections" -lt "$initial_connections" ]; then
            local dropped_connections=$((initial_connections - current_connections))
            log_event "WARNING" "Connection drop detected: $dropped_connections connections lost"
        fi
    done
    
    # Restore the network interface
    log_event "INFO" "Restoring network interface $interface"
    
    local restore_attempt=1
    while [ $restore_attempt -le $MAX_RETRIES ]; do
        if ip link set "$interface" up; then
            log_event "SUCCESS" "Network interface $interface restored successfully (attempt $restore_attempt)"
            break
        else
            log_event "WARNING" "Failed to restore interface $interface (attempt $restore_attempt/$MAX_RETRIES)"
            restore_attempt=$((restore_attempt + 1))
            sleep 5
        fi
    done
    
    if [ $restore_attempt -gt $MAX_RETRIES ]; then
        log_event "ERROR" "Failed to restore network interface after $MAX_RETRIES attempts"
        send_notification "RESTORATION_FAILED" "Critical: Unable to restore network interface $interface"
        return 1
    fi
    
    # Wait for interface to fully come online
    log_event "INFO" "Waiting for interface to fully initialize..."
    sleep 30
    
    # Verify restoration
    local final_status=$(get_interface_status "$interface")
    local recovery_connections=$(get_connection_count)
    local failure_end=$(date +%s)
    local total_downtime=$((failure_end - failure_start))
    
    log_event "INFO" "Post-recovery status - Interface: $final_status, Active connections: $recovery_connections"
    log_event "INFO" "Total downtime: ${total_downtime} seconds"
    
    # Send recovery notification
    send_notification "RECOVERY_COMPLETE" "AP failure simulation completed - Service restored after ${total_downtime}s"
    
    # Generate summary report
    cat >> "$LOG_FILE" << EOF

=== AP FAILURE SIMULATION SUMMARY ===
Start Time: $(date -d "@$failure_start" '+%Y-%m-%d %H:%M:%S')
End Time: $(date -d "@$failure_end" '+%Y-%m-%d %H:%M:%S')
Total Downtime: ${total_downtime} seconds (${downtime_minutes} minutes planned)
Interface: $interface
Initial Connections: $initial_connections
Recovery Connections: $recovery_connections
Connection Impact: $((initial_connections - recovery_connections)) connections affected
Status: $([ "$final_status" = "UP" ] && echo "SUCCESS" || echo "FAILED")

EOF
    
    return 0
}

# Function to run pre-flight checks
pre_flight_checks() {
    log_event "INFO" "Running pre-flight checks..."
    
    # Check if interface exists
    if [ "$(get_interface_status "$INTERFACE")" = "NOT_FOUND" ]; then
        log_event "ERROR" "Network interface $INTERFACE not found"
        exit 1
    fi
    
    # Check if interface is currently up
    if [ "$(get_interface_status "$INTERFACE")" != "UP" ]; then
        log_event "ERROR" "Network interface $INTERFACE is not currently up"
        exit 1
    fi
    
    # Check system load
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    local load_threshold=5.0
    
    if (( $(echo "$load_avg > $load_threshold" | bc -l) )); then
        log_event "WARNING" "System load is high ($load_avg). Consider postponing chaos test."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_event "INFO" "Chaos test cancelled by user due to high system load"
            exit 0
        fi
    fi
    
    # Check available disk space for logs
    local disk_usage=$(df /var/log | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt 90 ]; then
        log_event "WARNING" "Low disk space in /var/log (${disk_usage}% used)"
    fi
    
    log_event "SUCCESS" "Pre-flight checks completed"
}

# Function to display usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

LiveOpsLab AP Failure Simulation Script

Options:
    -i, --interface INTERFACE    Network interface to disable (default: eth0)
    -t, --time MINUTES          Downtime duration in minutes (default: 3)
    -l, --log-file FILE         Log file path (default: /var/log/chaos-engineering.log)
    -n, --no-confirm            Skip confirmation prompt
    -d, --dry-run               Show what would be done without executing
    -h, --help                  Show this help message

Examples:
    $0                          # Use default settings (eth0, 3 minutes)
    $0 -i ens5 -t 5            # Target ens5 interface for 5 minutes
    $0 --dry-run                # Preview the operation
    $0 --no-confirm -t 1        # Quick 1-minute test without confirmation

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
        -t|--time)
            DOWNTIME_MINUTES="$2"
            shift 2
            ;;
        -l|--log-file)
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
    echo -e "${BLUE}=== LiveOpsLab Chaos Engineering - AP Failure Simulation ===${NC}"
    echo
    
    # Check if this is a dry run
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}DRY RUN MODE - No actual changes will be made${NC}"
        echo "Would disable interface: $INTERFACE"
        echo "Would wait for: $DOWNTIME_MINUTES minutes"
        echo "Would log to: $LOG_FILE"
        exit 0
    fi
    
    # Root check
    check_root
    
    # Create log file if it doesn't exist
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    
    # Pre-flight checks
    pre_flight_checks
    
    # Confirmation prompt
    if [ "$NO_CONFIRM" != true ]; then
        echo -e "${YELLOW}WARNING: This will simulate an AP failure by disabling $INTERFACE for $DOWNTIME_MINUTES minutes${NC}"
        echo "This will cause service disruption and connection drops."
        echo
        read -p "Are you sure you want to continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_event "INFO" "AP failure simulation cancelled by user"
            exit 0
        fi
    fi
    
    # Record test start
    log_event "INFO" "=== Starting AP Failure Chaos Test ==="
    log_event "INFO" "Target interface: $INTERFACE"
    log_event "INFO" "Planned downtime: $DOWNTIME_MINUTES minutes"
    log_event "INFO" "Executed by: $(whoami)"
    log_event "INFO" "System: $(hostname) ($(uname -r))"
    
    # Execute the simulation
    if simulate_ap_failure "$INTERFACE" "$DOWNTIME_MINUTES"; then
        log_event "SUCCESS" "AP failure simulation completed successfully"
        echo -e "${GREEN}✅ AP failure simulation completed successfully${NC}"
    else
        log_event "ERROR" "AP failure simulation failed"
        echo -e "${RED}❌ AP failure simulation failed${NC}"
        exit 1
    fi
    
    log_event "INFO" "=== AP Failure Chaos Test Complete ==="
}

# Trap signals for cleanup
trap 'log_event "WARNING" "AP failure simulation interrupted by signal"; exit 130' INT TERM

# Execute main function
main "$@"
