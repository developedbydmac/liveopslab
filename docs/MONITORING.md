# LiveOpsLab Monitoring and Observability Guide

## 📊 Comprehensive Monitoring Setup

The LiveOpsLab venue infrastructure includes a complete observability stack with multi-zone monitoring, chaos event tracking, and centralized logging.

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    LiveOpsLab Monitoring Stack                  │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐        │
│  │   FanWiFi   │    │ VisitorWiFi │    │  Backstage  │        │
│  │    Zone     │    │    Zone     │    │    Zone     │        │
│  │             │    │             │    │             │        │
│  │ NodeExporter│    │ NodeExporter│    │ NodeExporter│        │
│  │    :9100    │    │    :9100    │    │    :9100    │        │
│  │             │    │             │    │             │        │
│  │ CloudWatch  │    │ CloudWatch  │    │ CloudWatch  │        │
│  │   Agent     │    │   Agent     │    │   Agent     │        │
│  └─────────────┘    └─────────────┘    └─────────────┘        │
│         │                   │                   │              │
│         └───────────────────┼───────────────────┘              │
│                             │                                  │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │              Backstage Monitoring Hub                   │  │
│  │                                                         │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │  │
│  │  │ Prometheus  │  │   Grafana   │  │   Logging   │    │  │
│  │  │    :9090    │  │    :3000    │  │             │    │  │
│  │  │             │  │             │  │ S3 Bucket   │    │  │
│  │  │ - Metrics   │  │ - Dashboard │  │ CloudWatch  │    │  │
│  │  │ - Alerts    │  │ - Viz       │  │ Log Groups  │    │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘    │  │
│  └─────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## 🎯 Monitoring Features

### Zone-Based Metrics Collection
- **FanWiFi Zone**: Public network monitoring with connection tracking
- **VisitorWiFi Zone**: Staff network performance metrics  
- **Backstage Zone**: Management infrastructure monitoring
- **Cross-Zone**: Comparative analytics and health checks

### Real-Time Dashboards
- **Venue Overview**: Multi-zone availability and performance
- **Zone-Specific**: Detailed metrics per network tier
- **Chaos Events**: Timeline of resilience testing activities
- **Custom Alerts**: Automated incident detection

### Comprehensive Logging
- **Application Logs**: Nginx access/error logs per zone
- **System Logs**: OS-level events and performance data
- **Chaos Logs**: Structured chaos engineering event data
- **S3 Archive**: Long-term log retention with lifecycle policies

## 🚀 Quick Start Monitoring

### 1. Deploy with Monitoring Enabled

```bash
# Configure monitoring in terraform.tfvars
enable_cloudwatch_monitoring = true
enable_chaos_testing = true

# Deploy infrastructure
terraform apply
```

### 2. Access Monitoring Interfaces

After deployment, access these endpoints:

```bash
# Get monitoring URLs
terraform output monitoring_endpoints

# Access Grafana Dashboard
open http://<backstage-ip>:3000
# Login: admin / liveopslab123

# Access Prometheus Metrics
open http://<backstage-ip>:9090
```

### 3. Verify Monitoring Setup

```bash
# Check all Prometheus targets are UP
curl http://<backstage-ip>:9090/api/v1/targets

# Test individual zone metrics
curl http://<fanwifi-private-ip>:9100/metrics
curl http://<visitorwifi-private-ip>:9100/metrics  
curl http://<backstage-private-ip>:9100/metrics
```

## 📈 Grafana Dashboards

### Venue Overview Dashboard
- **Zone Availability**: Real-time UP/DOWN status for all zones
- **CPU Usage**: Comparative CPU utilization across zones
- **Memory Usage**: Memory consumption trends by zone
- **Network Traffic**: Ingress/egress bandwidth by zone
- **Chaos Events**: Timeline of chaos engineering activities

### Key Metrics Tracked
- System health (CPU, Memory, Disk, Network)
- Application performance (Nginx, custom apps)
- Network connectivity and latency
- Chaos engineering event frequency
- Alert notification status

## 🔍 CloudWatch Integration

### Custom Namespaces
- `LiveOpsLab/FanWiFi` - Public zone metrics
- `LiveOpsLab/VisitorWiFi` - Staff zone metrics  
- `LiveOpsLab/Backstage` - Management zone metrics
- `LiveOpsLab/ChaosEvents` - Chaos engineering events

### Log Groups Structure
```
/aws/ec2/fanwifi       - FanWiFi zone logs
/aws/ec2/visitorwifi   - VisitorWiFi zone logs
/aws/ec2/backstage     - Backstage zone logs
/aws/ec2/chaos-events  - Cross-zone chaos events
```

## 🧪 Chaos Event Monitoring

### Event Logging
Chaos events are automatically logged with structured data:

```json
{
  "timestamp": "2025-07-28T14:32:15Z",
  "instance_id": "i-1234567890abcdef0", 
  "zone": "FanWiFi",
  "event_type": "ap_failure",
  "status": "started",
  "details": "Network interface disabled for 180 seconds"
}
```

### Chaos Metrics
- Event frequency by zone
- Event duration tracking
- Recovery time measurement
- Impact assessment

### Alerting on Chaos Events
Prometheus alerts trigger on:
- Unexpected chaos events
- Long-running chaos scenarios
- Failed chaos recoveries
- Cross-zone impact detection

## 📦 S3 Log Storage

### Bucket Structure
```
liveopslab-venue-logs-<suffix>/
├── logs/
│   ├── fanwifi/
│   │   ├── nginx-access.log
│   │   ├── nginx-error.log  
│   │   └── chaos-events.log
│   ├── visitorwifi/
│   │   ├── nginx-access.log
│   │   └── chaos-events.log
│   ├── backstage/
│   │   ├── nginx-access.log
│   │   ├── setup.log
│   │   └── chaos-events.log
│   └── chaos-events/
│       └── aggregated-events.log
```

### Lifecycle Management
- **Standard Storage**: 0-30 days
- **Infrequent Access**: 30-90 days  
- **Glacier**: 90+ days
- **Expiration**: 365 days

## 🚨 Alerting Configuration

### Built-in Alerts
- **Instance Down**: Zone unavailable > 1 minute
- **High CPU**: > 80% for 2+ minutes
- **High Memory**: < 20% available for 2+ minutes
- **Chaos Event**: Any chaos activity detected

### Custom Alert Examples

```yaml
# High network traffic alert
- alert: HighNetworkTraffic
  expr: rate(node_network_receive_bytes_total[5m]) > 100000000
  for: 2m
  labels:
    severity: warning
  annotations:
    summary: "High network traffic on {{ $labels.zone }}"

# Repeated chaos events
- alert: FrequentChaosEvents  
  expr: increase(chaos_event_total[10m]) > 3
  for: 0m
  labels:
    severity: info
  annotations:
    summary: "Multiple chaos events in {{ $labels.zone }}"
```

## 🔧 Advanced Configuration

### Custom Metrics
Add custom application metrics:

```bash
# Install Prometheus client library
pip install prometheus_client

# Example Python metric
from prometheus_client import Counter, Histogram
venue_requests = Counter('venue_requests_total', 'Total requests', ['zone'])
```

### Extended Dashboards
Import additional Grafana dashboards:
- Node Exporter Full
- AWS CloudWatch
- Nginx monitoring  
- Custom application dashboards

### Log Analysis
Query logs with CloudWatch Insights:

```sql
fields @timestamp, zone, event_type, details
| filter event_type = "ap_failure"
| stats count() by zone
| sort @timestamp desc
```

## 🎛️ Operations Guide

### Daily Monitoring Tasks
1. Check Grafana dashboards for anomalies
2. Review CloudWatch alarms
3. Verify S3 log uploads
4. Monitor chaos event frequency

### Weekly Tasks  
1. Review Prometheus target health
2. Check log retention policies
3. Update alerting rules as needed
4. Analyze chaos engineering trends

### Troubleshooting
- **Missing Metrics**: Check Node Exporter service status
- **Dashboard Issues**: Verify Prometheus data source
- **Log Gaps**: Check CloudWatch agent configuration
- **S3 Upload Failures**: Verify IAM permissions

This comprehensive monitoring setup provides complete visibility into your venue infrastructure, enabling proactive operations and effective chaos engineering practices.
