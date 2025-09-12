# LiveOpsLab Chaos Engineering Suite 🎭

A comprehensive chaos engineering toolkit designed to test the resilience and monitoring capabilities of your LiveOpsLab venue infrastructure. This suite simulates real-world failures and performance degradations to validate system robustness.

## 🎯 Overview

The chaos engineering suite consists of four main components:

1. **AP Failure Simulator** - Simulates network interface failures
2. **Network Latency Simulator** - Introduces network latency and packet loss
3. **CPU Spike Simulator** - Creates high CPU load scenarios
4. **Chaos Orchestrator** - Coordinates and schedules chaos events

## 🛠️ Scripts Description

### 1. AP Failure Simulator (`ap-failure-simulator.sh`)

Simulates Access Point failures by temporarily disabling network interfaces to test:
- Network redundancy and failover
- Monitoring and alerting systems
- User experience during outages
- Recovery procedures

**Key Features:**
- Configurable downtime duration (default: 3 minutes)
- Comprehensive logging and monitoring
- Automatic interface restoration
- CloudWatch and Prometheus integration
- Connection tracking during outage

### 2. Network Latency Simulator (`network-latency-simulator.sh`)

Introduces controlled network degradation to simulate:
- High latency conditions
- Packet loss scenarios
- Ticket scanning delays
- API response slowdowns

**Key Features:**
- Configurable latency and jitter (default: 500ms±100ms)
- Adjustable packet loss percentage (default: 5%)
- Traffic control using Linux `tc` (netem)
- Real-time performance monitoring
- Automatic cleanup on completion

### 3. CPU Spike Simulator (`cpu-spike-simulator.sh`)

Creates controlled CPU load scenarios to test:
- System performance under stress
- Application responsiveness
- Auto-scaling behaviors
- Resource monitoring and alerting

**Key Features:**
- Multiple spike patterns (sustained, burst, oscillating, realistic)
- Configurable CPU load percentage (default: 80%)
- Core-specific targeting
- Memory and process monitoring
- Graceful cleanup of stress processes

### 4. Chaos Orchestrator (`chaos-orchestrator.sh`)

Master controller that coordinates chaos events with:
- Automated scheduling (default: every 30 minutes)
- HTTP webhook endpoints for manual triggering
- Business hours awareness
- Event weighting and randomization
- Comprehensive logging and notifications

## 🚀 Quick Start

### Installation

1. **Make scripts executable:**
   ```bash
   chmod +x chaos-scripts/*.sh
   ```

2. **Install dependencies:**
   ```bash
   # For network latency simulation
   sudo yum install -y iproute2
   
   # For enhanced monitoring (optional)
   sudo yum install -y bc curl
   ```

3. **Deploy to your instances:**
   ```bash
   # Copy scripts to each EC2 instance
   scp -i ~/.ssh/liveopslab-key chaos-scripts/*.sh ec2-user@<instance-ip>:~/
   ```

### Basic Usage

#### Manual Chaos Testing

```bash
# Test AP failure (3-minute outage)
sudo ./ap-failure-simulator.sh

# Test network latency (500ms latency, 5% loss for 5 minutes)
sudo ./network-latency-simulator.sh

# Test CPU spike (80% load for 5 minutes)
sudo ./cpu-spike-simulator.sh

# Test with custom parameters
sudo ./ap-failure-simulator.sh -t 5 -i eth0
sudo ./network-latency-simulator.sh -l 300 -p 10 -t 10
sudo ./cpu-spike-simulator.sh -l 90 -s burst -t 8
```

#### Automated Chaos Orchestration

```bash
# Start automated chaos orchestrator
sudo ./chaos-orchestrator.sh start

# Check status
./chaos-orchestrator.sh status

# Manually trigger specific events
sudo ./chaos-orchestrator.sh trigger ap_failure
sudo ./chaos-orchestrator.sh trigger network_latency
sudo ./chaos-orchestrator.sh trigger cpu_spike
sudo ./chaos-orchestrator.sh trigger random

# Stop orchestrator
sudo ./chaos-orchestrator.sh stop
```

#### Webhook API Usage

```bash
# Trigger chaos via HTTP (useful for CI/CD or external tools)
curl -X POST http://localhost:8888/chaos/trigger \
     -H "Content-Type: application/json" \
     -d '{"event":"ap_failure"}'

# Check status
curl http://localhost:8888/chaos/status

# Stop all chaos events
curl -X POST http://localhost:8888/chaos/stop
```

## ⚙️ Configuration

### Chaos Orchestrator Configuration

The orchestrator uses `/etc/chaos-engineering.conf` for configuration:

```bash
# Global settings
CHAOS_INTERVAL=30           # Minutes between events
ENABLE_SCHEDULER=true       # Enable automatic scheduling
ENABLE_WEBHOOK=true         # Enable HTTP endpoints
WEBHOOK_PORT=8888          # Webhook server port

# Event weights (probability)
AP_FAILURE_WEIGHT=30       # 30% chance
LATENCY_WEIGHT=40          # 40% chance  
CPU_SPIKE_WEIGHT=30        # 30% chance

# Business hours (24-hour format)
BUSINESS_START_HOUR=9
BUSINESS_END_HOUR=17
WEEKEND_CHAOS=false        # No chaos on weekends
NIGHT_CHAOS=false          # No chaos outside business hours

# Safety limits
MIN_INTERVAL_MINUTES=15    # Minimum time between events
MAX_DAILY_EVENTS=10        # Maximum events per day
```

### Individual Script Options

Each script supports extensive customization:

#### AP Failure Simulator
```bash
./ap-failure-simulator.sh [OPTIONS]

Options:
  -i, --interface INTERFACE    # Network interface (default: eth0)
  -t, --time MINUTES          # Downtime duration (default: 3)
  -n, --no-confirm            # Skip confirmation
  -d, --dry-run               # Preview mode
  -h, --help                  # Show help
```

#### Network Latency Simulator
```bash
./network-latency-simulator.sh [OPTIONS]

Options:
  -i, --interface INTERFACE    # Network interface (default: eth0)
  -l, --latency MS            # Base latency (default: 500)
  -j, --jitter MS             # Jitter variation (default: 100)
  -p, --packet-loss PERCENT   # Packet loss (default: 5)
  -t, --time MINUTES          # Duration (default: 5)
  -c, --cleanup               # Clean up rules only
```

#### CPU Spike Simulator
```bash
./cpu-spike-simulator.sh [OPTIONS]

Options:
  -l, --load PERCENT          # CPU load target (default: 80)
  -t, --time MINUTES          # Duration (default: 5)
  -s, --spike-type TYPE       # sustained|burst|oscillating|realistic
  -c, --cores COUNT           # CPU cores to stress
  -k, --kill                  # Kill running stress processes
```

## 📊 Monitoring and Logging

### Log Files

All chaos events are logged to `/var/log/chaos-engineering.log`:

```bash
# View recent events
tail -f /var/log/chaos-engineering.log

# View orchestrator logs
./chaos-orchestrator.sh logs 100
```

### Metrics Integration

The scripts integrate with multiple monitoring systems:

#### CloudWatch Metrics
- Automatic metrics push to `LiveOpsLab/ChaosEngineering` namespace
- Event counts and durations tracked
- Requires AWS CLI configuration

#### Prometheus Integration
- Pushgateway support for metrics
- Set `PROMETHEUS_PUSHGATEWAY` environment variable
- Custom metrics for each chaos type

#### System Logging
- Events logged to syslog with `chaos-engineering` tag
- Integration with centralized logging systems

### Performance Data

Scripts generate detailed performance logs:

```bash
# Network performance during latency test
/tmp/network-performance-*.log

# CPU monitoring during spike test  
/tmp/cpu-spike-monitoring-*.log

# System metrics in CSV format for analysis
timestamp,cpu_usage,load_1min,memory_usage,process_count
2025-01-15 14:30:00,85.2,2.1,67.4,156
```

## 🔒 Security and Safety

### Safety Mechanisms

1. **Pre-flight Checks**: System health validation before chaos
2. **Time Limits**: Maximum duration enforcement
3. **Business Hours**: Respect operational schedules
4. **Rate Limiting**: Minimum intervals between events
5. **Daily Limits**: Maximum events per day
6. **Graceful Cleanup**: Automatic restoration on interruption

### Access Control

- Scripts require root privileges for network/system modifications
- Configuration files protected with 600 permissions
- PID files prevent multiple orchestrator instances
- Signal handling for graceful shutdown

### Network Interface Safety

```bash
# Backup network configuration before use
sudo cp /etc/sysconfig/network-scripts/ifcfg-eth0 /etc/sysconfig/network-scripts/ifcfg-eth0.backup

# Scripts automatically restore interfaces
# Manual recovery if needed:
sudo ip link set eth0 up
sudo systemctl restart network
```

## 🎭 Chaos Scenarios

### Venue-Specific Scenarios

#### 1. Fan WiFi Outage
Simulates AP failure during peak usage:
```bash
# Target FanWiFi instance
sudo ./chaos-orchestrator.sh trigger ap_failure
```

#### 2. Ticket Scanning Delays  
Simulates network latency affecting payment processing:
```bash
# High latency with packet loss
sudo ./network-latency-simulator.sh -l 800 -j 200 -p 8 -t 10
```

#### 3. Show Time CPU Spike
Simulates high load during event peak:
```bash
# Realistic application load pattern
sudo ./cpu-spike-simulator.sh -s realistic -l 90 -t 15
```

#### 4. Multi-Component Failure
Tests cascading failure scenarios:
```bash
# Heavy combination test
sudo ./chaos-orchestrator.sh trigger combo_heavy
```

### Testing Strategies

#### 1. Gradual Introduction
Start with low-impact tests:
```bash
# Light network degradation
sudo ./network-latency-simulator.sh -l 200 -p 2 -t 3

# Moderate CPU load
sudo ./cpu-spike-simulator.sh -l 60 -t 2
```

#### 2. Peak Time Testing
Schedule chaos during expected high load:
```bash
# Configure business hours in /etc/chaos-engineering.conf
BUSINESS_START_HOUR=14  # Event start time
BUSINESS_END_HOUR=18    # Event end time
```

#### 3. Recovery Validation
Test monitoring and alerting:
```bash
# Quick failure to test alert timing
sudo ./ap-failure-simulator.sh -t 1
```

## 🔧 Troubleshooting

### Common Issues

#### 1. Network Interface Not Found
```bash
# List available interfaces
ip link show

# Update script configuration
sudo ./ap-failure-simulator.sh -i ens5
```

#### 2. Traffic Control (tc) Not Available
```bash
# Install iproute2 package
sudo yum install -y iproute2

# Verify tc installation
which tc
```

#### 3. Permission Denied
```bash
# Ensure root privileges
sudo ./chaos-orchestrator.sh start

# Check script permissions
chmod +x chaos-scripts/*.sh
```

#### 4. Webhook Port In Use
```bash
# Check port usage
sudo netstat -tlnp | grep 8888

# Use different port
sudo ./chaos-orchestrator.sh start --webhook-port 9999
```

### Recovery Procedures

#### Emergency Cleanup
```bash
# Stop all chaos processes
sudo pkill -f "chaos.*simulator"

# Clean up network rules
sudo tc qdisc del dev eth0 root 2>/dev/null || true

# Restart networking if needed
sudo systemctl restart network
```

#### Log Analysis
```bash
# Check for errors
grep ERROR /var/log/chaos-engineering.log

# View performance impact
grep "CPU\|Memory\|Load" /var/log/chaos-engineering.log

# Check system messages
sudo journalctl -f -u network
```

## 🚀 Integration with LiveOpsLab

### Terraform Integration

Add chaos scripts to your EC2 user data:

```hcl
# Add to main.tf user_data sections
user_data = base64encode(templatefile("${path.module}/user_data/fanwifi_init.sh", {
  hostname = "fanwifi-server"
  enable_chaos = var.enable_chaos_testing
}))
```

### Monitoring Dashboard Integration

Add chaos metrics to your Grafana dashboards:

```json
{
  "title": "Chaos Engineering Events",
  "type": "stat",
  "targets": [
    {
      "query": "sum(rate(chaos_event_total[5m]))",
      "legendFormat": "Events/min"
    }
  ]
}
```

### Automated Testing Pipeline

Integrate with CI/CD:

```yaml
# .github/workflows/chaos-testing.yml
chaos_test:
  runs-on: self-hosted
  steps:
    - name: Run Chaos Test
      run: |
        ssh -i ${{ secrets.SSH_KEY }} ec2-user@${{ vars.INSTANCE_IP }} \
          "sudo ./chaos-orchestrator.sh trigger network_latency"
```

## 📈 Metrics and Reporting

### Key Metrics to Track

1. **Availability Metrics**
   - Service uptime during chaos
   - Recovery time objectives (RTO)
   - Mean time to recovery (MTTR)

2. **Performance Metrics**
   - Response time degradation
   - Throughput impact
   - Error rate increases

3. **System Metrics**
   - CPU utilization patterns
   - Memory usage spikes
   - Network latency measurements

### Sample Dashboards

Create monitoring dashboards to track:

```bash
# System performance during chaos
- CPU usage over time
- Network latency measurements
- Connection success rates
- Error logs and alerts

# Business impact metrics
- User session duration
- Transaction success rates
- Support ticket volume
- Revenue impact
```

## 🎯 Best Practices

### 1. Start Small
Begin with low-impact tests and gradually increase intensity.

### 2. Monitor Everything
Ensure comprehensive monitoring before starting chaos tests.

### 3. Business Hours Awareness
Respect operational schedules and user expectations.

### 4. Documentation
Maintain detailed logs of chaos experiments and outcomes.

### 5. Team Communication
Notify relevant teams before conducting chaos tests.

### 6. Rollback Plans
Always have immediate recovery procedures ready.

## 🤝 Contributing

To extend the chaos suite:

1. Follow the existing script structure and logging patterns
2. Include comprehensive error handling and cleanup
3. Add configuration options for flexibility
4. Document new chaos scenarios
5. Test thoroughly in non-production environments

## 📄 License

This chaos engineering suite is provided as part of the LiveOpsLab project for educational and testing purposes.

---

**LiveOpsLab Chaos Engineering** - Building resilient venue infrastructure through controlled failure testing 🎭
