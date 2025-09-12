#!/bin/bash
# LiveOpsLab Chaos Engineering - CPU Spike Simulator
# Simulates high CPU load to test system resilience

set -e

# Configuration
SCRIPT_NAME="CPU Spike Simulator"
LOG_FILE="/var/log/chaos-engineering.log"
CPU_LOAD_PERCENT=80     # Target CPU load percentage
DURATION_MINUTES=5      # Duration of CPU spike
CORES=$(nproc)          # Number of CPU cores
SPIKE_TYPE="sustained"  # sustained, burst, or oscillating

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Array to store background process PIDs
declare -a STRESS_PIDS=()

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
        log_event "WARNING" "Running as non-root user. Some system metrics may be limited."
    fi
}

# Function to get current CPU usage
get_cpu_usage() {
    if command -v top &> /dev/null; then
        top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}' | sed 's/[^0-9.]//g'
    elif [ -f /proc/loadavg ]; then
        awk '{print $1}' /proc/loadavg
    else
        echo "0"
    fi
}

# Function to get system load average
get_load_average() {
    if [ -f /proc/loadavg ]; then
        awk '{print $1 " " $2 " " $3}' /proc/loadavg
    else
        echo "0.00 0.00 0.00"
    fi
}

# Function to get memory usage
get_memory_usage() {
    if [ -f /proc/meminfo ]; then
        local total_mem=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        local avail_mem=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
        local used_mem=$((total_mem - avail_mem))
        local mem_percent=$((used_mem * 100 / total_mem))
        echo "$mem_percent"
    else
        echo "0"
    fi
}

# Function to get running processes count
get_process_count() {
    ps aux | wc -l
}

# Function to create CPU stress
create_cpu_stress() {
    local target_load=$1
    local cores=$2
    local duration_seconds=$3
    
    log_event "INFO" "Creating CPU stress: ${target_load}% load across $cores cores for ${duration_seconds}s"
    
    # Calculate how many cores to stress
    local cores_to_stress=$(( (target_load * cores) / 100 ))
    if [ $cores_to_stress -eq 0 ]; then
        cores_to_stress=1
    fi
    
    log_event "INFO" "Stressing $cores_to_stress out of $cores CPU cores"
    
    # Create stress processes
    for ((i=1; i<=cores_to_stress; i++)); do
        (
            # CPU-intensive loop
            while true; do
                # Perform CPU-intensive operations
                for j in {1..1000}; do
                    echo "scale=1000; 4*a(1)" | bc -l > /dev/null 2>&1 || true
                done
                
                # Small sleep to allow for load adjustment
                sleep 0.01
            done
        ) &
        
        local pid=$!
        STRESS_PIDS+=($pid)
        log_event "INFO" "Started stress process $i with PID $pid"
        
        # Use taskset to pin process to specific CPU if available
        if command -v taskset &> /dev/null; then
            taskset -cp $((i-1)) $pid &>/dev/null || true
        fi
    done
    
    # Monitor and adjust load
    local start_time=$(date +%s)
    local end_time=$((start_time + duration_seconds))
    
    while [ $(date +%s) -lt $end_time ]; do
        local current_load=$(get_cpu_usage)
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        local remaining=$((end_time - current_time))
        
        log_event "INFO" "CPU stress progress: ${elapsed}s elapsed, ${remaining}s remaining, Load: ${current_load}%"
        
        # Adjust stress if load is too low or too high
        if (( $(echo "$current_load < $((target_load - 10))" | bc -l) )); then
            log_event "WARNING" "CPU load below target, current: ${current_load}%"
        elif (( $(echo "$current_load > $((target_load + 20))" | bc -l) )); then
            log_event "WARNING" "CPU load above target, current: ${current_load}%"
        fi
        
        sleep 10
    done
    
    # Clean up stress processes
    cleanup_stress_processes
}

# Function to create burst CPU load
create_burst_cpu_stress() {
    local target_load=$1
    local cores=$2
    local duration_seconds=$3
    local burst_duration=30  # 30 second bursts
    local rest_duration=15   # 15 second rest
    
    log_event "INFO" "Creating burst CPU stress pattern"
    
    local start_time=$(date +%s)
    local end_time=$((start_time + duration_seconds))
    
    while [ $(date +%s) -lt $end_time ]; do
        local remaining=$((end_time - $(date +%s)))
        local this_burst_duration=$burst_duration
        
        if [ $remaining -lt $burst_duration ]; then
            this_burst_duration=$remaining
        fi
        
        if [ $this_burst_duration -gt 0 ]; then
            log_event "INFO" "Starting CPU burst for ${this_burst_duration}s"
            create_cpu_stress $target_load $cores $this_burst_duration
            
            # Rest period if we have time remaining
            remaining=$((end_time - $(date +%s)))
            if [ $remaining -gt 0 ] && [ $remaining -gt $rest_duration ]; then
                log_event "INFO" "CPU burst rest period for ${rest_duration}s"
                sleep $rest_duration
            fi
        fi
    done
}

# Function to create oscillating CPU load
create_oscillating_cpu_stress() {
    local max_load=$1
    local cores=$2
    local duration_seconds=$3
    local cycle_duration=60  # 60 second cycles
    
    log_event "INFO" "Creating oscillating CPU stress pattern"
    
    local start_time=$(date +%s)
    local end_time=$((start_time + duration_seconds))
    
    while [ $(date +%s) -lt $end_time ]; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        local cycle_position=$((elapsed % cycle_duration))
        
        # Calculate load based on sine wave pattern
        local load_factor=$(echo "scale=2; (s($cycle_position * 3.14159 / $cycle_duration) + 1) / 2" | bc -l)
        local current_target=$(echo "scale=0; $max_load * $load_factor / 1" | bc)
        
        log_event "INFO" "Oscillating load target: ${current_target}%"
        
        # Short stress period
        if [ $current_target -gt 10 ]; then
            create_cpu_stress $current_target $cores 10
        else
            sleep 10
        fi
    done
}

# Function to simulate realistic application CPU spike
simulate_application_cpu_spike() {
    local duration_seconds=$1
    
    log_event "INFO" "Simulating realistic application CPU spike"
    
    # Simulate database query overload
    (
        for i in {1..100}; do
            # Simulate complex database operations
            find /var /tmp -type f -name "*.log" 2>/dev/null | head -1000 | xargs grep -l "error" 2>/dev/null || true
            sleep 0.1
        done
    ) &
    STRESS_PIDS+=($!)
    
    # Simulate image processing load
    (
        for i in {1..50}; do
            # Generate and compress random data
            dd if=/dev/urandom bs=1M count=10 2>/dev/null | gzip > /dev/null
            sleep 0.5
        done
    ) &
    STRESS_PIDS+=($!)
    
    # Simulate API request processing
    (
        for i in {1..200}; do
            # JSON parsing simulation
            echo '{"users":[{"id":1,"name":"test"}],"data":{"items":[1,2,3,4,5]}}' | python3 -m json.tool > /dev/null 2>&1 || true
            # Hash computation
            echo "test-data-$i" | md5sum > /dev/null 2>&1 || echo "test-data-$i" | shasum > /dev/null 2>&1 || true
            sleep 0.05
        done
    ) &
    STRESS_PIDS+=($!)
    
    # Wait for duration
    sleep $duration_seconds
    
    # Clean up
    cleanup_stress_processes
}

# Function to cleanup stress processes
cleanup_stress_processes() {
    log_event "INFO" "Cleaning up stress processes..."
    
    for pid in "${STRESS_PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            log_event "INFO" "Terminating stress process PID $pid"
            kill -TERM "$pid" 2>/dev/null || true
            
            # Wait a bit for graceful termination
            sleep 2
            
            # Force kill if still running
            if kill -0 "$pid" 2>/dev/null; then
                log_event "WARNING" "Force killing stress process PID $pid"
                kill -KILL "$pid" 2>/dev/null || true
            fi
        fi
    done
    
    # Clear the array
    STRESS_PIDS=()
    
    # Also clean up any orphaned stress processes
    pkill -f "bc -l" 2>/dev/null || true
    
    log_event "SUCCESS" "Stress processes cleaned up"
}

# Function to send notification to monitoring systems
send_notification() {
    local event_type=$1
    local message=$2
    
    # Send to CloudWatch if AWS CLI is available
    if command -v aws &> /dev/null; then
        aws cloudwatch put-metric-data \
            --namespace "LiveOpsLab/ChaosEngineering" \
            --metric-data MetricName="CPUSpikeEvent",Value=1,Unit=Count \
            --region "${AWS_REGION:-us-east-1}" &>/dev/null || true
    fi
    
    # Log to syslog
    logger -t "chaos-engineering" "$event_type: $message"
    
    # Send to Prometheus if available
    if command -v curl &> /dev/null && [ -n "$PROMETHEUS_PUSHGATEWAY" ]; then
        curl -X POST "$PROMETHEUS_PUSHGATEWAY/metrics/job/chaos-engineering/instance/$(hostname)" \
             --data-binary "cpu_spike_event{type=\"$event_type\"} 1" &>/dev/null || true
    fi
}

# Function to monitor system during spike
monitor_system_during_spike() {
    local duration_seconds=$1
    local monitoring_interval=15
    
    log_event "INFO" "Starting system monitoring during CPU spike"
    
    # Create monitoring log
    local monitor_log="/tmp/cpu-spike-monitoring-$(date +%s).log"
    echo "timestamp,cpu_usage,load_1min,load_5min,load_15min,memory_usage,process_count" > "$monitor_log"
    
    local start_time=$(date +%s)
    local end_time=$((start_time + duration_seconds))
    
    while [ $(date +%s) -lt $end_time ]; do
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        local cpu_usage=$(get_cpu_usage)
        local load_avg=$(get_load_average)
        local memory_usage=$(get_memory_usage)
        local process_count=$(get_process_count)
        
        # Parse load average
        local load_1min=$(echo $load_avg | awk '{print $1}')
        local load_5min=$(echo $load_avg | awk '{print $2}')
        local load_15min=$(echo $load_avg | awk '{print $3}')
        
        log_event "INFO" "System metrics - CPU: ${cpu_usage}%, Load: $load_1min, Memory: ${memory_usage}%, Processes: $process_count"
        
        # Log to CSV
        echo "$timestamp,$cpu_usage,$load_1min,$load_5min,$load_15min,$memory_usage,$process_count" >> "$monitor_log"
        
        # Alert on extreme conditions
        if (( $(echo "$cpu_usage > 95" | bc -l) )); then
            log_event "CRITICAL" "Extreme CPU usage detected: ${cpu_usage}%"
            send_notification "HIGH_CPU_ALERT" "Critical CPU usage: ${cpu_usage}%"
        fi
        
        if (( $(echo "$load_1min > $((CORES * 2))" | bc -l) )); then
            log_event "CRITICAL" "High system load detected: $load_1min"
        fi
        
        sleep $monitoring_interval
    done
    
    log_event "SUCCESS" "System monitoring completed. Data saved to: $monitor_log"
    return 0
}

# Function to run pre-flight checks
pre_flight_checks() {
    log_event "INFO" "Running pre-flight checks..."
    
    # Check current system load
    local current_load=$(get_cpu_usage)
    if (( $(echo "$current_load > 80" | bc -l) )); then
        log_event "WARNING" "System already under high load: ${current_load}%"
        read -p "Continue with CPU spike test? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_event "INFO" "CPU spike test cancelled due to existing high load"
            exit 0
        fi
    fi
    
    # Check available memory
    local memory_usage=$(get_memory_usage)
    if [ "$memory_usage" -gt 90 ]; then
        log_event "WARNING" "High memory usage detected: ${memory_usage}%"
    fi
    
    # Check disk space for logs
    local disk_usage=$(df /var/log | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt 90 ]; then
        log_event "WARNING" "Low disk space in /var/log: ${disk_usage}% used"
    fi
    
    log_event "SUCCESS" "Pre-flight checks completed"
}

# Function to display usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

LiveOpsLab CPU Spike Simulation Script

Options:
    -l, --load PERCENT          Target CPU load percentage (default: 80)
    -t, --time MINUTES          Duration in minutes (default: 5)
    -s, --spike-type TYPE       Spike type: sustained, burst, oscillating, realistic (default: sustained)
    -c, --cores COUNT           Number of CPU cores to stress (default: auto-detect)
    -f, --log-file FILE         Log file path (default: /var/log/chaos-engineering.log)
    -n, --no-confirm            Skip confirmation prompt
    -d, --dry-run               Show what would be done without executing
    -m, --monitor-only          Only monitor system, don't create load
    -k, --kill                  Kill any running stress processes and exit
    -h, --help                  Show this help message

Spike Types:
    sustained    - Constant high CPU load for entire duration
    burst        - Alternating high load bursts with rest periods
    oscillating  - Gradually varying load in wave pattern
    realistic    - Simulate real application CPU spike patterns

Examples:
    $0                          # Default sustained 80% load for 5 minutes
    $0 -l 90 -t 10 -s burst     # 90% load in burst pattern for 10 minutes
    $0 -s realistic -t 3        # Realistic application spike for 3 minutes
    $0 --monitor-only -t 5      # Monitor system for 5 minutes without load
    $0 --kill                   # Kill any running stress processes

Environment Variables:
    AWS_REGION                  AWS region for CloudWatch metrics
    PROMETHEUS_PUSHGATEWAY      Prometheus pushgateway URL for metrics

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -l|--load)
            CPU_LOAD_PERCENT="$2"
            shift 2
            ;;
        -t|--time)
            DURATION_MINUTES="$2"
            shift 2
            ;;
        -s|--spike-type)
            SPIKE_TYPE="$2"
            shift 2
            ;;
        -c|--cores)
            CORES="$2"
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
        -m|--monitor-only)
            MONITOR_ONLY=true
            shift
            ;;
        -k|--kill)
            KILL_STRESS=true
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
    echo -e "${BLUE}=== LiveOpsLab Chaos Engineering - CPU Spike Simulator ===${NC}"
    echo
    
    # Create log file if it doesn't exist
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    
    # Handle kill mode
    if [ "$KILL_STRESS" = true ]; then
        log_event "INFO" "Killing any running stress processes..."
        cleanup_stress_processes
        pkill -f "cpu.*stress" 2>/dev/null || true
        echo -e "${GREEN}✅ Stress processes terminated${NC}"
        exit 0
    fi
    
    # Handle dry run
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}DRY RUN MODE - No actual load will be created${NC}"
        echo "Would create CPU load: ${CPU_LOAD_PERCENT}%"
        echo "Would use spike type: $SPIKE_TYPE"
        echo "Would target cores: $CORES"
        echo "Would run for: $DURATION_MINUTES minutes"
        echo "Would log to: $LOG_FILE"
        exit 0
    fi
    
    # Handle monitor-only mode
    if [ "$MONITOR_ONLY" = true ]; then
        log_event "INFO" "Monitor-only mode - tracking system metrics for $DURATION_MINUTES minutes"
        monitor_system_during_spike $((DURATION_MINUTES * 60))
        exit 0
    fi
    
    # Pre-flight checks
    pre_flight_checks
    
    # Confirmation prompt
    if [ "$NO_CONFIRM" != true ]; then
        echo -e "${YELLOW}WARNING: This will create high CPU load on the system${NC}"
        echo "CPU Load: ${CPU_LOAD_PERCENT}%"
        echo "Spike Type: $SPIKE_TYPE"
        echo "Target Cores: $CORES"
        echo "Duration: $DURATION_MINUTES minutes"
        echo
        echo "This may affect system performance and user experience."
        echo
        read -p "Are you sure you want to continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_event "INFO" "CPU spike simulation cancelled by user"
            exit 0
        fi
    fi
    
    # Record test start
    log_event "INFO" "=== Starting CPU Spike Chaos Test ==="
    log_event "INFO" "Target load: ${CPU_LOAD_PERCENT}%"
    log_event "INFO" "Spike type: $SPIKE_TYPE"
    log_event "INFO" "Target cores: $CORES"
    log_event "INFO" "Duration: $DURATION_MINUTES minutes"
    log_event "INFO" "Executed by: $(whoami)"
    log_event "INFO" "System: $(hostname) ($(uname -r))"
    
    # Get baseline metrics
    local baseline_cpu=$(get_cpu_usage)
    local baseline_load=$(get_load_average)
    local baseline_memory=$(get_memory_usage)
    
    log_event "INFO" "Baseline metrics - CPU: ${baseline_cpu}%, Load: $baseline_load, Memory: ${baseline_memory}%"
    
    # Send start notification
    send_notification "CPU_SPIKE_START" "CPU spike simulation started - ${CPU_LOAD_PERCENT}% target load, type: $SPIKE_TYPE"
    
    # Start monitoring in background
    monitor_system_during_spike $((DURATION_MINUTES * 60)) &
    local monitor_pid=$!
    
    # Execute the appropriate spike type
    local duration_seconds=$((DURATION_MINUTES * 60))
    
    case $SPIKE_TYPE in
        "sustained")
            create_cpu_stress $CPU_LOAD_PERCENT $CORES $duration_seconds
            ;;
        "burst")
            create_burst_cpu_stress $CPU_LOAD_PERCENT $CORES $duration_seconds
            ;;
        "oscillating")
            create_oscillating_cpu_stress $CPU_LOAD_PERCENT $CORES $duration_seconds
            ;;
        "realistic")
            simulate_application_cpu_spike $duration_seconds
            ;;
        *)
            log_event "ERROR" "Unknown spike type: $SPIKE_TYPE"
            exit 1
            ;;
    esac
    
    # Wait for monitoring to complete
    wait $monitor_pid 2>/dev/null || true
    
    # Wait for system to stabilize
    log_event "INFO" "Waiting for system to stabilize..."
    sleep 30
    
    # Get final metrics
    local final_cpu=$(get_cpu_usage)
    local final_load=$(get_load_average)
    local final_memory=$(get_memory_usage)
    
    log_event "INFO" "Final metrics - CPU: ${final_cpu}%, Load: $final_load, Memory: ${final_memory}%"
    
    # Send completion notification
    send_notification "CPU_SPIKE_COMPLETE" "CPU spike simulation completed - System load normalized"
    
    # Generate summary
    cat >> "$LOG_FILE" << EOF

=== CPU SPIKE SIMULATION SUMMARY ===
Start Time: $(date '+%Y-%m-%d %H:%M:%S')
Duration: $DURATION_MINUTES minutes
Spike Type: $SPIKE_TYPE
Target Load: ${CPU_LOAD_PERCENT}%
Target Cores: $CORES
Baseline CPU: ${baseline_cpu}%
Final CPU: ${final_cpu}%
System: $(hostname)

EOF
    
    log_event "SUCCESS" "CPU spike simulation completed successfully"
    echo -e "${GREEN}✅ CPU spike simulation completed successfully${NC}"
    log_event "INFO" "=== CPU Spike Chaos Test Complete ==="
}

# Trap signals for cleanup
trap 'log_event "WARNING" "CPU spike simulation interrupted - cleaning up"; cleanup_stress_processes; exit 130' INT TERM

# Execute main function
main "$@"
