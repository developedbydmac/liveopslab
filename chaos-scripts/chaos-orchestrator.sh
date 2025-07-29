#!/bin/bash
# LiveOpsLab Chaos Engineering - Master Orchestrator
# Coordinates chaos events with scheduling and endpoint triggering

set -e

# Configuration
SCRIPT_NAME="Chaos Orchestrator"
LOG_FILE="/var/log/chaos-engineering.log"
CONFIG_FILE="/etc/chaos-engineering.conf"
PID_FILE="/var/run/chaos-orchestrator.pid"
CHAOS_INTERVAL=30  # Default interval in minutes
WEBHOOK_PORT=8888  # Port for chaos triggering endpoint

# Chaos script paths
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
AP_FAILURE_SCRIPT="$SCRIPT_DIR/ap-failure-simulator.sh"
LATENCY_SCRIPT="$SCRIPT_DIR/network-latency-simulator.sh"
CPU_SPIKE_SCRIPT="$SCRIPT_DIR/cpu-spike-simulator.sh"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Chaos event types and their configurations
declare -A CHAOS_EVENTS=(
    ["ap_failure"]="AP Network Failure"
    ["network_latency"]="Network Latency/Packet Loss"
    ["cpu_spike"]="CPU Spike Load"
    ["combo_light"]="Light Combination Test"
    ["combo_heavy"]="Heavy Combination Test"
)

# Default chaos configurations
declare -A AP_FAILURE_CONFIG=(
    ["interface"]="eth0"
    ["duration"]="3"
    ["enabled"]="true"
    ["weight"]="30"
)

declare -A LATENCY_CONFIG=(
    ["interface"]="eth0"
    ["latency"]="300"
    ["jitter"]="50"
    ["packet_loss"]="3"
    ["duration"]="5"
    ["enabled"]="true"
    ["weight"]="40"
)

declare -A CPU_SPIKE_CONFIG=(
    ["load"]="75"
    ["duration"]="4"
    ["spike_type"]="sustained"
    ["enabled"]="true"
    ["weight"]="30"
)

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
        log_event "ERROR" "This script must be run as root to execute chaos tests"
        exit 1
    fi
}

# Function to load configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        log_event "INFO" "Loading configuration from $CONFIG_FILE"
        source "$CONFIG_FILE"
    else
        log_event "INFO" "No configuration file found, using defaults"
        create_default_config
    fi
}

# Function to create default configuration file
create_default_config() {
    log_event "INFO" "Creating default configuration file at $CONFIG_FILE"
    
    cat > "$CONFIG_FILE" << 'EOF'
# LiveOpsLab Chaos Engineering Configuration

# Global settings
CHAOS_INTERVAL=30           # Minutes between automatic chaos events
ENABLE_SCHEDULER=true       # Enable automatic scheduling
ENABLE_WEBHOOK=true         # Enable webhook endpoint
WEBHOOK_PORT=8888          # Port for webhook server
LOG_LEVEL="INFO"           # DEBUG, INFO, WARNING, ERROR
MAX_CONCURRENT_CHAOS=1     # Maximum simultaneous chaos events

# Notification settings
SLACK_WEBHOOK=""           # Slack webhook URL for notifications
TEAMS_WEBHOOK=""           # Microsoft Teams webhook URL
EMAIL_RECIPIENTS=""        # Comma-separated email addresses

# AP Failure Configuration
AP_FAILURE_ENABLED=true
AP_FAILURE_INTERFACE="eth0"
AP_FAILURE_DURATION=3      # Minutes
AP_FAILURE_WEIGHT=30       # Probability weight

# Network Latency Configuration  
LATENCY_ENABLED=true
LATENCY_INTERFACE="eth0"
LATENCY_MS=300            # Base latency in milliseconds
LATENCY_JITTER=50         # Jitter in milliseconds
LATENCY_PACKET_LOSS=3     # Packet loss percentage
LATENCY_DURATION=5        # Minutes
LATENCY_WEIGHT=40         # Probability weight

# CPU Spike Configuration
CPU_SPIKE_ENABLED=true
CPU_SPIKE_LOAD=75         # Target CPU percentage
CPU_SPIKE_DURATION=4      # Minutes
CPU_SPIKE_TYPE="sustained" # sustained, burst, oscillating, realistic
CPU_SPIKE_WEIGHT=30       # Probability weight

# Business Hours (24-hour format)
BUSINESS_START_HOUR=9
BUSINESS_END_HOUR=17
WEEKEND_CHAOS=false       # Allow chaos on weekends
NIGHT_CHAOS=false         # Allow chaos outside business hours

# Safety settings
MIN_INTERVAL_MINUTES=15   # Minimum time between chaos events
MAX_DAILY_EVENTS=10       # Maximum chaos events per day
REQUIRE_CONFIRMATION=false # Require manual confirmation for each event

EOF
    
    chmod 600 "$CONFIG_FILE"
    log_event "SUCCESS" "Default configuration created"
}

# Function to send notifications
send_notification() {
    local event_type=$1
    local message=$2
    local severity=${3:-"INFO"}
    
    # Log notification
    log_event "$severity" "NOTIFICATION: $event_type - $message"
    
    # Send to Slack if configured
    if [ -n "$SLACK_WEBHOOK" ]; then
        local color="good"
        case $severity in
            "ERROR"|"CRITICAL") color="danger" ;;
            "WARNING") color="warning" ;;
        esac
        
        local payload=$(cat << EOF
{
    "attachments": [
        {
            "color": "$color",
            "title": "LiveOpsLab Chaos Engineering",
            "fields": [
                {
                    "title": "Event",
                    "value": "$event_type",
                    "short": true
                },
                {
                    "title": "Message", 
                    "value": "$message",
                    "short": false
                },
                {
                    "title": "Timestamp",
                    "value": "$(date '+%Y-%m-%d %H:%M:%S')",
                    "short": true
                }
            ]
        }
    ]
}
EOF
        )
        
        curl -X POST -H 'Content-type: application/json' \
             --data "$payload" \
             "$SLACK_WEBHOOK" &>/dev/null || true
    fi
    
    # Send to CloudWatch
    if command -v aws &> /dev/null; then
        aws cloudwatch put-metric-data \
            --namespace "LiveOpsLab/ChaosEngineering" \
            --metric-data MetricName="ChaosEvent",Value=1,Unit=Count,Dimensions=EventType="$event_type" \
            --region "${AWS_REGION:-us-east-1}" &>/dev/null || true
    fi
    
    # Send to syslog
    logger -t "chaos-orchestrator" "$event_type: $message"
}

# Function to check if chaos is allowed at current time
is_chaos_allowed() {
    local current_hour=$(date +%H)
    local current_dow=$(date +%u)  # 1=Monday, 7=Sunday
    
    # Check weekend restriction
    if [ "$WEEKEND_CHAOS" = "false" ] && [ "$current_dow" -gt 5 ]; then
        log_event "INFO" "Chaos not allowed on weekends"
        return 1
    fi
    
    # Check business hours restriction
    if [ "$NIGHT_CHAOS" = "false" ]; then
        if [ "$current_hour" -lt "$BUSINESS_START_HOUR" ] || [ "$current_hour" -ge "$BUSINESS_END_HOUR" ]; then
            log_event "INFO" "Chaos not allowed outside business hours ($current_hour:00)"
            return 1
        fi
    fi
    
    return 0
}

# Function to select random chaos event
select_chaos_event() {
    local total_weight=0
    local enabled_events=()
    
    # Calculate total weight of enabled events
    if [ "$AP_FAILURE_ENABLED" = "true" ]; then
        total_weight=$((total_weight + AP_FAILURE_WEIGHT))
        enabled_events+=("ap_failure")
    fi
    
    if [ "$LATENCY_ENABLED" = "true" ]; then
        total_weight=$((total_weight + LATENCY_WEIGHT))
        enabled_events+=("network_latency")
    fi
    
    if [ "$CPU_SPIKE_ENABLED" = "true" ]; then
        total_weight=$((total_weight + CPU_SPIKE_WEIGHT))
        enabled_events+=("cpu_spike")
    fi
    
    if [ $total_weight -eq 0 ] || [ ${#enabled_events[@]} -eq 0 ]; then
        log_event "WARNING" "No chaos events enabled"
        return 1
    fi
    
    # Generate random number
    local random_num=$((RANDOM % total_weight))
    local cumulative_weight=0
    
    # Select event based on weight
    if [ "$AP_FAILURE_ENABLED" = "true" ]; then
        cumulative_weight=$((cumulative_weight + AP_FAILURE_WEIGHT))
        if [ $random_num -lt $cumulative_weight ]; then
            echo "ap_failure"
            return 0
        fi
    fi
    
    if [ "$LATENCY_ENABLED" = "true" ]; then
        cumulative_weight=$((cumulative_weight + LATENCY_WEIGHT))
        if [ $random_num -lt $cumulative_weight ]; then
            echo "network_latency"
            return 0
        fi
    fi
    
    if [ "$CPU_SPIKE_ENABLED" = "true" ]; then
        echo "cpu_spike"
        return 0
    fi
    
    # Fallback to first enabled event
    echo "${enabled_events[0]}"
}

# Function to execute chaos event
execute_chaos_event() {
    local event_type=$1
    local manual=${2:-false}
    
    log_event "INFO" "Executing chaos event: $event_type (manual: $manual)"
    send_notification "CHAOS_START" "Starting chaos event: ${CHAOS_EVENTS[$event_type]}" "WARNING"
    
    local success=false
    local start_time=$(date +%s)
    
    case $event_type in
        "ap_failure")
            if [ -x "$AP_FAILURE_SCRIPT" ]; then
                log_event "INFO" "Starting AP failure simulation"
                if $AP_FAILURE_SCRIPT -i "$AP_FAILURE_INTERFACE" -t "$AP_FAILURE_DURATION" --no-confirm; then
                    success=true
                fi
            else
                log_event "ERROR" "AP failure script not found or not executable: $AP_FAILURE_SCRIPT"
            fi
            ;;
            
        "network_latency")
            if [ -x "$LATENCY_SCRIPT" ]; then
                log_event "INFO" "Starting network latency simulation"
                if $LATENCY_SCRIPT -i "$LATENCY_INTERFACE" -l "$LATENCY_MS" -j "$LATENCY_JITTER" \
                   -p "$LATENCY_PACKET_LOSS" -t "$LATENCY_DURATION" --no-confirm; then
                    success=true
                fi
            else
                log_event "ERROR" "Network latency script not found or not executable: $LATENCY_SCRIPT"
            fi
            ;;
            
        "cpu_spike")
            if [ -x "$CPU_SPIKE_SCRIPT" ]; then
                log_event "INFO" "Starting CPU spike simulation"
                if $CPU_SPIKE_SCRIPT -l "$CPU_SPIKE_LOAD" -t "$CPU_SPIKE_DURATION" \
                   -s "$CPU_SPIKE_TYPE" --no-confirm; then
                    success=true
                fi
            else
                log_event "ERROR" "CPU spike script not found or not executable: $CPU_SPIKE_SCRIPT"
            fi
            ;;
            
        "combo_light")
            log_event "INFO" "Starting light combination chaos test"
            # Reduced intensity combination
            if [ -x "$LATENCY_SCRIPT" ] && [ -x "$CPU_SPIKE_SCRIPT" ]; then
                $LATENCY_SCRIPT -l 200 -j 30 -p 2 -t 3 --no-confirm &
                sleep 60
                $CPU_SPIKE_SCRIPT -l 60 -t 2 -s sustained --no-confirm &
                wait
                success=true
            fi
            ;;
            
        "combo_heavy")
            log_event "INFO" "Starting heavy combination chaos test"
            # Full intensity combination
            if [ -x "$AP_FAILURE_SCRIPT" ] && [ -x "$LATENCY_SCRIPT" ] && [ -x "$CPU_SPIKE_SCRIPT" ]; then
                $CPU_SPIKE_SCRIPT -l 85 -t 6 -s burst --no-confirm &
                sleep 120
                $LATENCY_SCRIPT -l 500 -j 100 -p 5 -t 4 --no-confirm &
                sleep 60
                $AP_FAILURE_SCRIPT -t 2 --no-confirm &
                wait
                success=true
            fi
            ;;
            
        *)
            log_event "ERROR" "Unknown chaos event type: $event_type"
            return 1
            ;;
    esac
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [ "$success" = true ]; then
        log_event "SUCCESS" "Chaos event '$event_type' completed successfully in ${duration}s"
        send_notification "CHAOS_COMPLETE" "Chaos event completed: ${CHAOS_EVENTS[$event_type]} (${duration}s)" "INFO"
        return 0
    else
        log_event "ERROR" "Chaos event '$event_type' failed after ${duration}s"
        send_notification "CHAOS_FAILED" "Chaos event failed: ${CHAOS_EVENTS[$event_type]}" "ERROR"
        return 1
    fi
}

# Function to start webhook server
start_webhook_server() {
    log_event "INFO" "Starting webhook server on port $WEBHOOK_PORT"
    
    # Create webhook script
    local webhook_script="/tmp/chaos-webhook-$$.sh"
    cat > "$webhook_script" << 'EOF'
#!/bin/bash
while true; do
    {
        read -r request
        read -r headers
        
        # Parse HTTP method and path
        method=$(echo "$request" | awk '{print $1}')
        path=$(echo "$request" | awk '{print $2}')
        
        # Read POST data if present
        content_length=0
        while IFS= read -r header; do
            [[ "$header" == $'\r' ]] && break
            if [[ "$header" =~ ^Content-Length:[[:space:]]*([0-9]+) ]]; then
                content_length=${BASH_REMATCH[1]}
            fi
        done
        
        post_data=""
        if [ "$content_length" -gt 0 ]; then
            post_data=$(head -c "$content_length")
        fi
        
        # Handle different endpoints
        case "$path" in
            "/chaos/trigger")
                if [ "$method" = "POST" ]; then
                    event_type=$(echo "$post_data" | grep -o '"event":"[^"]*' | cut -d'"' -f4)
                    if [ -z "$event_type" ]; then
                        event_type="random"
                    fi
                    
                    # Trigger chaos event
                    echo "Triggering chaos event: $event_type" >> /var/log/chaos-engineering.log
                    /usr/local/bin/chaos-orchestrator.sh trigger "$event_type" &
                    
                    echo -e "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{\"status\":\"triggered\",\"event\":\"$event_type\"}"
                else
                    echo -e "HTTP/1.1 405 Method Not Allowed\r\n\r\n"
                fi
                ;;
                
            "/chaos/status")
                running_chaos=$(pgrep -f "chaos.*simulator" | wc -l)
                echo -e "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{\"status\":\"running\",\"active_chaos\":$running_chaos}"
                ;;
                
            "/chaos/stop")
                if [ "$method" = "POST" ]; then
                    pkill -f "chaos.*simulator" || true
                    echo -e "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{\"status\":\"stopped\"}"
                else
                    echo -e "HTTP/1.1 405 Method Not Allowed\r\n\r\n"
                fi
                ;;
                
            *)
                echo -e "HTTP/1.1 404 Not Found\r\n\r\n"
                ;;
        esac
    } | nc -l -p WEBHOOK_PORT_PLACEHOLDER
done
EOF
    
    # Replace placeholder with actual port
    sed -i "s/WEBHOOK_PORT_PLACEHOLDER/$WEBHOOK_PORT/g" "$webhook_script"
    chmod +x "$webhook_script"
    
    # Start webhook server in background
    nohup "$webhook_script" > /dev/null 2>&1 &
    local webhook_pid=$!
    
    echo "$webhook_pid" > "/var/run/chaos-webhook.pid"
    log_event "SUCCESS" "Webhook server started with PID $webhook_pid"
    
    # Clean up webhook script after a delay
    (sleep 5; rm -f "$webhook_script") &
}

# Function to stop webhook server
stop_webhook_server() {
    if [ -f "/var/run/chaos-webhook.pid" ]; then
        local webhook_pid=$(cat "/var/run/chaos-webhook.pid")
        if kill -0 "$webhook_pid" 2>/dev/null; then
            kill "$webhook_pid"
            log_event "INFO" "Webhook server stopped (PID: $webhook_pid)"
        fi
        rm -f "/var/run/chaos-webhook.pid"
    fi
}

# Function to run chaos scheduler
run_scheduler() {
    log_event "INFO" "Starting chaos scheduler with interval: $CHAOS_INTERVAL minutes"
    
    local last_event_time=0
    local daily_event_count=0
    local last_date=$(date +%Y-%m-%d)
    
    while true; do
        local current_time=$(date +%s)
        local current_date=$(date +%Y-%m-%d)
        
        # Reset daily counter at midnight
        if [ "$current_date" != "$last_date" ]; then
            daily_event_count=0
            last_date="$current_date"
            log_event "INFO" "Daily event counter reset"
        fi
        
        # Check if enough time has passed since last event
        local time_since_last=$((current_time - last_event_time))
        local min_interval_seconds=$((MIN_INTERVAL_MINUTES * 60))
        local chaos_interval_seconds=$((CHAOS_INTERVAL * 60))
        
        if [ $time_since_last -ge $chaos_interval_seconds ] && [ $time_since_last -ge $min_interval_seconds ]; then
            # Check daily event limit
            if [ $daily_event_count -ge $MAX_DAILY_EVENTS ]; then
                log_event "INFO" "Daily event limit reached ($daily_event_count/$MAX_DAILY_EVENTS)"
            elif is_chaos_allowed; then
                # Select and execute chaos event
                local selected_event=$(select_chaos_event)
                if [ $? -eq 0 ] && [ -n "$selected_event" ]; then
                    log_event "INFO" "Scheduler triggering chaos event: $selected_event"
                    
                    if execute_chaos_event "$selected_event" false; then
                        last_event_time=$current_time
                        daily_event_count=$((daily_event_count + 1))
                    fi
                fi
            fi
        fi
        
        # Sleep for 1 minute before next check
        sleep 60
    done
}

# Function to display status
show_status() {
    echo -e "${BLUE}=== LiveOpsLab Chaos Engineering Status ===${NC}"
    echo
    
    # Check if orchestrator is running
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "${GREEN}✅ Orchestrator Status: Running (PID: $pid)${NC}"
        else
            echo -e "${RED}❌ Orchestrator Status: Not Running (stale PID file)${NC}"
            rm -f "$PID_FILE"
        fi
    else
        echo -e "${RED}❌ Orchestrator Status: Not Running${NC}"
    fi
    
    # Check active chaos processes
    local active_chaos=$(pgrep -f "chaos.*simulator" | wc -l)
    echo "🔥 Active Chaos Processes: $active_chaos"
    
    # Show recent events from log
    echo
    echo "📊 Recent Events (last 10):"
    if [ -f "$LOG_FILE" ]; then
        tail -10 "$LOG_FILE" | while read line; do
            echo "   $line"
        done
    else
        echo "   No log file found"
    fi
    
    # Show configuration summary
    echo
    echo "⚙️  Configuration:"
    echo "   Interval: $CHAOS_INTERVAL minutes"
    echo "   Webhook Port: $WEBHOOK_PORT"
    echo "   Log File: $LOG_FILE"
    echo "   Config File: $CONFIG_FILE"
}

# Function to display usage
show_usage() {
    cat << EOF
Usage: $0 COMMAND [OPTIONS]

LiveOpsLab Chaos Engineering Orchestrator

Commands:
    start                       Start the chaos orchestrator daemon
    stop                        Stop the chaos orchestrator daemon  
    restart                     Restart the chaos orchestrator daemon
    status                      Show current status
    trigger EVENT               Manually trigger a chaos event
    list-events                 List available chaos events
    config                      Show current configuration
    test-webhook               Test webhook endpoint
    logs [LINES]               Show recent log entries (default: 50)

Chaos Events:
    ap_failure                 Simulate AP network failure
    network_latency            Simulate network latency/packet loss
    cpu_spike                  Simulate CPU load spike
    combo_light                Light combination test
    combo_heavy                Heavy combination test
    random                     Randomly selected event

Options:
    -c, --config FILE          Use custom configuration file
    -l, --log-file FILE        Use custom log file
    -d, --daemon               Run in daemon mode
    -v, --verbose              Enable verbose logging
    -h, --help                 Show this help message

Examples:
    $0 start                   # Start orchestrator daemon
    $0 trigger ap_failure      # Manually trigger AP failure
    $0 trigger random          # Trigger random chaos event
    $0 logs 100               # Show last 100 log entries

Webhook Endpoints:
    POST /chaos/trigger        Trigger chaos event
    GET  /chaos/status         Get orchestrator status
    POST /chaos/stop           Stop all chaos events

EOF
}

# Function to handle daemon mode
run_daemon() {
    # Check if already running
    if [ -f "$PID_FILE" ]; then
        local existing_pid=$(cat "$PID_FILE")
        if kill -0 "$existing_pid" 2>/dev/null; then
            log_event "ERROR" "Orchestrator already running with PID $existing_pid"
            exit 1
        else
            rm -f "$PID_FILE"
        fi
    fi
    
    # Create PID file
    echo $$ > "$PID_FILE"
    
    # Set up signal handlers
    trap 'log_event "INFO" "Received SIGTERM, shutting down gracefully"; cleanup_and_exit' TERM
    trap 'log_event "INFO" "Received SIGINT, shutting down gracefully"; cleanup_and_exit' INT
    
    log_event "INFO" "=== Starting LiveOpsLab Chaos Orchestrator Daemon ==="
    log_event "INFO" "PID: $$"
    log_event "INFO" "Configuration: $CONFIG_FILE"
    log_event "INFO" "Log file: $LOG_FILE"
    
    # Start webhook server if enabled
    if [ "$ENABLE_WEBHOOK" = "true" ]; then
        start_webhook_server
    fi
    
    # Send startup notification
    send_notification "ORCHESTRATOR_START" "Chaos Engineering Orchestrator started" "INFO"
    
    # Start scheduler if enabled
    if [ "$ENABLE_SCHEDULER" = "true" ]; then
        run_scheduler
    else
        log_event "INFO" "Scheduler disabled, running in webhook-only mode"
        while true; do
            sleep 300  # 5 minute intervals
        done
    fi
}

# Function to cleanup and exit
cleanup_and_exit() {
    log_event "INFO" "Shutting down chaos orchestrator..."
    
    # Stop any running chaos events
    pkill -f "chaos.*simulator" 2>/dev/null || true
    
    # Stop webhook server
    stop_webhook_server
    
    # Remove PID file
    rm -f "$PID_FILE"
    
    # Send shutdown notification
    send_notification "ORCHESTRATOR_STOP" "Chaos Engineering Orchestrator stopped" "INFO"
    
    log_event "INFO" "=== Chaos Orchestrator Shutdown Complete ==="
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -l|--log-file)
            LOG_FILE="$2"
            shift 2
            ;;
        -d|--daemon)
            DAEMON_MODE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

# Main command handling
main() {
    local command=${1:-"help"}
    
    # Load configuration
    load_config
    
    # Create log file if it doesn't exist
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    
    case $command in
        "start")
            check_root
            run_daemon
            ;;
            
        "stop")
            if [ -f "$PID_FILE" ]; then
                local pid=$(cat "$PID_FILE")
                if kill -0 "$pid" 2>/dev/null; then
                    log_event "INFO" "Stopping chaos orchestrator (PID: $pid)"
                    kill -TERM "$pid"
                    echo -e "${GREEN}✅ Chaos orchestrator stopped${NC}"
                else
                    echo -e "${YELLOW}⚠️  Orchestrator not running (removing stale PID file)${NC}"
                    rm -f "$PID_FILE"
                fi
            else
                echo -e "${YELLOW}⚠️  Orchestrator not running${NC}"
            fi
            ;;
            
        "restart")
            $0 stop
            sleep 2
            $0 start
            ;;
            
        "status")
            show_status
            ;;
            
        "trigger")
            check_root
            local event_type=${2:-"random"}
            if [ "$event_type" = "random" ]; then
                event_type=$(select_chaos_event)
            fi
            
            if [[ -n "${CHAOS_EVENTS[$event_type]}" ]]; then
                log_event "INFO" "Manual trigger request for: $event_type"
                execute_chaos_event "$event_type" true
            else
                echo -e "${RED}❌ Unknown chaos event: $event_type${NC}"
                echo "Available events: ${!CHAOS_EVENTS[*]}"
                exit 1
            fi
            ;;
            
        "list-events")
            echo -e "${BLUE}Available Chaos Events:${NC}"
            for event in "${!CHAOS_EVENTS[@]}"; do
                echo -e "  ${GREEN}$event${NC} - ${CHAOS_EVENTS[$event]}"
            done
            ;;
            
        "config")
            echo -e "${BLUE}Current Configuration:${NC}"
            if [ -f "$CONFIG_FILE" ]; then
                cat "$CONFIG_FILE"
            else
                echo "No configuration file found at: $CONFIG_FILE"
            fi
            ;;
            
        "test-webhook")
            echo "Testing webhook endpoints..."
            local base_url="http://localhost:$WEBHOOK_PORT"
            
            echo "Status endpoint:"
            curl -s "$base_url/chaos/status" || echo "Failed to connect"
            
            echo -e "\nTrigger endpoint:"
            curl -s -X POST -H "Content-Type: application/json" \
                 -d '{"event":"random"}' "$base_url/chaos/trigger" || echo "Failed to connect"
            ;;
            
        "logs")
            local lines=${2:-50}
            if [ -f "$LOG_FILE" ]; then
                tail -n "$lines" "$LOG_FILE"
            else
                echo "Log file not found: $LOG_FILE"
            fi
            ;;
            
        "help"|*)
            show_usage
            ;;
    esac
}

# Make scripts executable
chmod +x "$AP_FAILURE_SCRIPT" 2>/dev/null || true
chmod +x "$LATENCY_SCRIPT" 2>/dev/null || true  
chmod +x "$CPU_SPIKE_SCRIPT" 2>/dev/null || true

# Execute main function
main "$@"
