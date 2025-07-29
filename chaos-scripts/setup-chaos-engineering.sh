#!/bin/bash
# LiveOpsLab Chaos Engineering Setup Script
# Installs and configures chaos engineering tools on EC2 instances

set -e

# Configuration
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
LOG_FILE="/var/log/chaos-setup.log"

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log_message() {
    local message=$1
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE"
}

print_header() {
    echo -e "${BLUE}"
    echo "=========================================="
    echo "  LiveOpsLab Chaos Engineering Setup"
    echo "=========================================="
    echo -e "${NC}"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}This script must be run as root${NC}"
        exit 1
    fi
}

install_dependencies() {
    log_message "Installing system dependencies..."
    
    # Update system
    yum update -y
    
    # Install required packages
    yum install -y \
        iproute2 \
        bc \
        curl \
        wget \
        net-tools \
        htop \
        nc \
        psmisc
    
    log_message "✅ Dependencies installed successfully"
}

setup_chaos_scripts() {
    log_message "Setting up chaos engineering scripts..."
    
    # Create installation directory
    local install_dir="/opt/chaos-engineering"
    mkdir -p "$install_dir"
    
    # Copy scripts
    cp "$SCRIPT_DIR"/*.sh "$install_dir/"
    chmod +x "$install_dir"/*.sh
    
    # Create symlinks in /usr/local/bin for easy access
    ln -sf "$install_dir/chaos-orchestrator.sh" /usr/local/bin/chaos-orchestrator
    ln -sf "$install_dir/ap-failure-simulator.sh" /usr/local/bin/chaos-ap-failure
    ln -sf "$install_dir/network-latency-simulator.sh" /usr/local/bin/chaos-latency
    ln -sf "$install_dir/cpu-spike-simulator.sh" /usr/local/bin/chaos-cpu-spike
    
    log_message "✅ Chaos scripts installed to $install_dir"
}

create_default_config() {
    log_message "Creating default configuration..."
    
    local config_file="/etc/chaos-engineering.conf"
    
    cat > "$config_file" << 'EOF'
# LiveOpsLab Chaos Engineering Configuration
# Automatically generated during installation

# Global settings
CHAOS_INTERVAL=30           # Minutes between automatic chaos events
ENABLE_SCHEDULER=true       # Enable automatic scheduling
ENABLE_WEBHOOK=true         # Enable webhook endpoint
WEBHOOK_PORT=8888          # Port for webhook server
LOG_LEVEL="INFO"           # DEBUG, INFO, WARNING, ERROR
MAX_CONCURRENT_CHAOS=1     # Maximum simultaneous chaos events

# Network interface detection (auto-detect primary interface)
PRIMARY_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)

# AP Failure Configuration
AP_FAILURE_ENABLED=true
AP_FAILURE_INTERFACE="$PRIMARY_INTERFACE"
AP_FAILURE_DURATION=3      # Minutes
AP_FAILURE_WEIGHT=30       # Probability weight

# Network Latency Configuration  
LATENCY_ENABLED=true
LATENCY_INTERFACE="$PRIMARY_INTERFACE"
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

# AWS Integration (if available)
AWS_REGION="${AWS_REGION:-$(curl -s http://169.254.169.254/latest/meta-data/placement/region 2>/dev/null || echo 'us-east-1')}"

# Notification settings (optional)
SLACK_WEBHOOK=""          # Slack webhook URL for notifications
TEAMS_WEBHOOK=""          # Microsoft Teams webhook URL
EMAIL_RECIPIENTS=""       # Comma-separated email addresses
PROMETHEUS_PUSHGATEWAY="" # Prometheus pushgateway URL

EOF
    
    chmod 600 "$config_file"
    log_message "✅ Configuration created at $config_file"
}

setup_systemd_service() {
    log_message "Setting up systemd service..."
    
    cat > /etc/systemd/system/chaos-orchestrator.service << 'EOF'
[Unit]
Description=LiveOpsLab Chaos Engineering Orchestrator
After=network.target
Wants=network-online.target

[Service]
Type=forking
User=root
Group=root
ExecStart=/usr/local/bin/chaos-orchestrator start
ExecStop=/usr/local/bin/chaos-orchestrator stop
ExecReload=/usr/local/bin/chaos-orchestrator restart
PIDFile=/var/run/chaos-orchestrator.pid
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable chaos-orchestrator
    
    log_message "✅ Systemd service configured"
}

setup_log_rotation() {
    log_message "Setting up log rotation..."
    
    cat > /etc/logrotate.d/chaos-engineering << 'EOF'
/var/log/chaos-engineering.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    sharedscripts
    postrotate
        systemctl reload chaos-orchestrator 2>/dev/null || true
    endscript
}
EOF
    
    log_message "✅ Log rotation configured"
}

create_monitoring_scripts() {
    log_message "Creating monitoring helper scripts..."
    
    # Chaos status check script
    cat > /usr/local/bin/chaos-status << 'EOF'
#!/bin/bash
# Quick chaos engineering status check

echo "=== LiveOpsLab Chaos Engineering Status ==="
echo ""

# Orchestrator status
if systemctl is-active --quiet chaos-orchestrator; then
    echo "🟢 Orchestrator: Running"
else
    echo "🔴 Orchestrator: Stopped"
fi

# Active chaos processes
active_chaos=$(pgrep -f "chaos.*simulator" | wc -l)
echo "🔥 Active Chaos: $active_chaos processes"

# Recent events
echo ""
echo "📊 Recent Events (last 5):"
tail -5 /var/log/chaos-engineering.log 2>/dev/null | sed 's/^/   /' || echo "   No events logged"

# System resources
echo ""
echo "💻 System Resources:"
echo "   CPU: $(top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | awk -F'%' '{print $1}')% used"
echo "   Memory: $(free | grep Mem | awk '{printf "%.1f%", $3/$2 * 100.0}') used"
echo "   Load: $(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')"

# Network interface status
primary_if=$(ip route | grep default | awk '{print $5}' | head -1)
if_status=$(ip link show "$primary_if" | grep -o "state [A-Z]*" | awk '{print $2}')
echo "   Network ($primary_if): $if_status"
EOF
    
    chmod +x /usr/local/bin/chaos-status
    
    # Quick chaos trigger script
    cat > /usr/local/bin/chaos-trigger << 'EOF'
#!/bin/bash
# Quick chaos event trigger

if [ $# -eq 0 ]; then
    echo "Usage: chaos-trigger <event_type>"
    echo ""
    echo "Available events:"
    echo "  ap_failure     - Simulate AP network failure"
    echo "  network_latency - Simulate network latency/packet loss"
    echo "  cpu_spike      - Simulate CPU load spike"
    echo "  random         - Randomly selected event"
    exit 1
fi

event_type=$1
echo "🎭 Triggering chaos event: $event_type"
chaos-orchestrator trigger "$event_type"
EOF
    
    chmod +x /usr/local/bin/chaos-trigger
    
    log_message "✅ Monitoring scripts created"
}

configure_firewall() {
    log_message "Configuring firewall for webhook endpoint..."
    
    # Open webhook port if firewall is active
    if systemctl is-active --quiet iptables; then
        iptables -I INPUT -p tcp --dport 8888 -j ACCEPT
        service iptables save
        log_message "✅ Firewall configured for webhook port 8888"
    else
        log_message "ℹ️  Firewall not active, skipping firewall configuration"
    fi
}

run_initial_test() {
    log_message "Running initial connectivity test..."
    
    # Test that scripts can run without errors
    if /opt/chaos-engineering/chaos-orchestrator.sh list-events &>/dev/null; then
        log_message "✅ Chaos orchestrator functioning correctly"
    else
        log_message "⚠️  Warning: Chaos orchestrator test failed"
    fi
    
    # Test webhook endpoint (if orchestrator is running)
    local webhook_test_result=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8888/chaos/status 2>/dev/null || echo "000")
    if [ "$webhook_test_result" = "200" ]; then
        log_message "✅ Webhook endpoint responding"
    else
        log_message "ℹ️  Webhook endpoint not yet active (normal for initial setup)"
    fi
}

show_completion_summary() {
    echo -e "${GREEN}"
    echo "=========================================="
    echo "   ✅ Setup Complete!"
    echo "=========================================="
    echo -e "${NC}"
    echo ""
    echo "🎭 LiveOpsLab Chaos Engineering is now installed!"
    echo ""
    echo "📂 Installation Details:"
    echo "   Scripts: /opt/chaos-engineering/"
    echo "   Config:  /etc/chaos-engineering.conf"
    echo "   Logs:    /var/log/chaos-engineering.log"
    echo ""
    echo "🚀 Quick Start Commands:"
    echo "   chaos-status                    # Check system status"
    echo "   chaos-orchestrator start        # Start automatic chaos"
    echo "   chaos-trigger random            # Trigger random chaos event"
    echo "   chaos-orchestrator status       # View orchestrator status"
    echo ""
    echo "🌐 Webhook Endpoints (port 8888):"
    echo "   POST /chaos/trigger             # Trigger chaos event"
    echo "   GET  /chaos/status              # Get status"
    echo "   POST /chaos/stop                # Stop all chaos"
    echo ""
    echo "📖 Documentation:"
    echo "   /opt/chaos-engineering/README.md"
    echo ""
    echo "⚠️  Important Notes:"
    echo "   • Scripts require root privileges"
    echo "   • Review /etc/chaos-engineering.conf before starting"
    echo "   • Test in non-production environment first"
    echo "   • Monitor system during chaos events"
    echo ""
    echo "🏁 To start automatic chaos orchestration:"
    echo "   sudo systemctl start chaos-orchestrator"
    echo ""
}

# Main execution
main() {
    print_header
    
    # Create log file
    touch "$LOG_FILE"
    
    log_message "🚀 Starting LiveOpsLab Chaos Engineering setup..."
    
    # Check prerequisites
    check_root
    
    # Installation steps
    install_dependencies
    setup_chaos_scripts
    create_default_config
    setup_systemd_service
    setup_log_rotation
    create_monitoring_scripts
    configure_firewall
    run_initial_test
    
    log_message "✅ Setup completed successfully"
    
    # Show completion summary
    show_completion_summary
}

# Run main function
main "$@"
