# 📟 Enhanced LiveOpsLab CLI with Webhook Integration

A comprehensive command-line interface for managing network incidents, monitoring access points, and sending alerts to Slack/Discord webhooks.

## 🎯 New Features Added

### 1. **Argparse-Based Commands**
- `simulate` - Trigger network incidents with optional webhook alerts
- `replay` - Re-run past incidents by ID from incident_log.json
- `ap-status` - Show detailed status for all 3 zones of a specific AP
- Enhanced `status` - Overall network health across all zones

### 2. **Webhook Alert Integration**
- **Slack Support**: Rich formatted messages with attachments
- **Discord Support**: Embedded messages with color coding
- **Human-readable alerts**: Emojis, timestamps, and fix suggestions
- **Platform selection**: Choose between Slack or Discord format

### 3. **Data Sources Integration**
- **incident_log.json**: Historical incident data for replay functionality
- **network_topology.json**: Real-time network state information
- **Cross-referencing**: Links incidents to current network status

## 🚀 Command Reference

### Basic Usage
```bash
python3 dashboard_cli.py [--webhook URL] [--platform slack|discord] <command> [options]
```

### Available Commands

#### 1. Overall Network Status
```bash
python3 dashboard_cli.py status
```
**Output**: Zone health percentages, affected APs, active incidents

#### 2. Access Point Detailed Status
```bash
python3 dashboard_cli.py ap-status AP-01
```
**Features**:
- All 3 zones (FanWiFi, VisitorWiFi, Backstage) 
- Performance metrics (latency, throughput, clients)
- Hardware details (model, location, IP address)
- Active incidents on the specific AP

#### 3. Simulate Network Incident
```bash
# Random incident
python3 dashboard_cli.py simulate

# Specific incident with webhook alert
python3 dashboard_cli.py \
  --webhook https://hooks.slack.com/services/YOUR/WEBHOOK/URL \
  --platform slack \
  simulate --ap AP-25 --zone FanWiFi --issue high_latency
```

#### 4. Replay Past Incident
```bash
python3 dashboard_cli.py replay 6b553063
```
**Features**:
- Uses incident_log.json for historical data
- Accepts full UUID or first 8 characters
- Re-simulates with same parameters
- Generates new incident ID

#### 5. Resolve Active Incident
```bash
python3 dashboard_cli.py resolve 1de67608-0a72-4666-a9a0-b69049ed1400
```

#### 6. Real-Time Monitoring
```bash
python3 dashboard_cli.py monitor --duration 120
```

#### 7. Complete Demonstration
```bash
python3 dashboard_cli.py demo
```

## 🔗 Webhook Integration

### Slack Webhook Format
```json
{
  "text": "🚨 *LiveOpsLab Network Alert* 🚨",
  "attachments": [
    {
      "color": "danger",
      "fields": [
        {
          "title": "⚡ Incident Details",
          "value": "*AP:* AP-42\n*Zone:* 🎭 Backstage\n*Issue:* Power Failure"
        },
        {
          "title": "🔍 Root Cause",
          "value": "Power budget exceeded on PoE switch"
        },
        {
          "title": "🔧 Recommended Fix", 
          "value": "Check PoE power budget and redistribute load"
        }
      ]
    }
  ]
}
```

### Discord Webhook Format
```json
{
  "embeds": [
    {
      "title": "🚨 LiveOpsLab Network Alert",
      "description": "⚡ **Power Failure** incident detected",
      "color": 15158332,
      "fields": [
        {
          "name": "📡 Access Point",
          "value": "AP-42"
        },
        {
          "name": "🎭 Affected Zone",
          "value": "Backstage"
        },
        {
          "name": "🔍 Root Cause",
          "value": "Power budget exceeded on PoE switch"
        }
      ]
    }
  ]
}
```

## 📊 Data Integration

### incident_log.json Structure
```json
[
  {
    "id": "6b553063-9c7f-4a30-bc75-6e98ae8d8dc8",
    "timestamp": "2025-07-29T14:47:06.812409",
    "ap_id": "AP-25",
    "zone": "FanWiFi", 
    "issue_type": "high_latency",
    "status": "down",
    "resolved": false,
    "switch_id": "Switch-09"
  }
]
```

### network_topology.json Structure
```json
{
  "access_points": [
    {
      "ap_id": "AP-01",
      "switch_id": "Switch-01",
      "location": {
        "floor": 1,
        "section": "North"
      },
      "zones": {
        "FanWiFi": {
          "status": "healthy",
          "latency_ms": 20,
          "connected_clients": 43,
          "throughput_mbps": 44.2
        }
      }
    }
  ]
}
```

## 🎨 Status Display Features

### Zone Status Colors
- 🟢 **Healthy**: < 50ms latency, normal operation
- 🟡 **Warning**: 50-100ms latency, degraded performance  
- 🔴 **Down**: > 100ms latency or offline

### Zone Emojis
- 🏟️ **FanWiFi**: General fan internet access
- 👥 **VisitorWiFi**: Visitor and guest access
- 🎭 **Backstage**: Staff and operational use

### Issue Type Emojis
- 🌐 **Network Connectivity**: Signal, cable, or switch issues
- ⚡ **Power Failure**: PoE budget or power supply problems
- 🔧 **Hardware Malfunction**: Radio, memory, or component failures
- 🐌 **High Latency**: Performance degradation issues
- 🔐 **Authentication Failure**: RADIUS, certificate, or AD problems

## 🔄 Replay Functionality

### How It Works
1. **Load History**: Reads incident_log.json for past incidents
2. **Find Target**: Matches full UUID or first 8 characters
3. **Extract Parameters**: Gets original AP, zone, and issue type
4. **Re-simulate**: Creates new incident with same parameters
5. **New Analysis**: Generates fresh root cause analysis
6. **New ID**: Assigns new UUID for tracking

### Use Cases
- **Testing**: Reproduce specific scenarios
- **Training**: Demonstrate incident response
- **Validation**: Verify fix effectiveness
- **Analysis**: Compare different root causes

## 🚨 Alert Function Details

### send_alert() Function
```python
def send_alert(ap_id, zone, issue_type, root_cause, fix_suggestion, 
               webhook_url=None, platform="slack"):
    """
    Send alert notification to Slack or Discord webhook.
    
    Args:
        ap_id: Access point ID
        zone: Zone name  
        issue_type: Type of issue
        root_cause: Root cause analysis
        fix_suggestion: Recommended fix
        webhook_url: Webhook URL for notifications
        platform: 'slack' or 'discord'
    """
```

### Alert Content
- **Timestamp**: Human-readable date/time
- **AP Details**: ID, zone, and issue type with emojis
- **Root Cause**: Intelligent analysis result
- **Fix Suggestion**: Actionable remediation steps
- **Visual Elements**: Color coding and emoji indicators

## 🧪 Testing Your Setup

### 1. Start Webhook Test Server
```bash
python3 webhook_test_server.py
# Server runs on http://localhost:9999
```

### 2. Test Slack Alert
```bash
python3 dashboard_cli.py \
  --webhook http://localhost:9999/webhook \
  --platform slack \
  simulate --ap AP-01 --zone FanWiFi --issue power_failure
```

### 3. Test Discord Alert
```bash
python3 dashboard_cli.py \
  --webhook http://localhost:9999/webhook \
  --platform discord \
  simulate --ap AP-02 --zone Backstage --issue network_connectivity
```

### 4. Run Complete Demo
```bash
python3 demo_enhanced_cli.py
```

## 🎯 Advanced Examples

### Production Webhook Usage
```bash
# Slack production webhook
python3 dashboard_cli.py \
  --webhook https://hooks.slack.com/services/T123/B456/xyz789 \
  --platform slack \
  simulate

# Discord production webhook  
python3 dashboard_cli.py \
  --webhook https://discord.com/api/webhooks/123456/abcdef \
  --platform discord \
  simulate --zone Backstage --issue hardware_malfunction
```

### Batch Operations
```bash
# Check multiple APs
for ap in AP-01 AP-15 AP-25; do
  python3 dashboard_cli.py ap-status $ap
done

# Replay multiple incidents
for incident in 6b553063 1de67608 18e3ce2b; do
  python3 dashboard_cli.py replay $incident
done
```

### Monitoring Scripts
```bash
# Continuous monitoring with alerts
python3 dashboard_cli.py \
  --webhook $SLACK_WEBHOOK \
  monitor --duration 3600  # 1 hour

# Scheduled incident simulation (cron job)
0 */2 * * * cd /path/to/liveopslab && python3 dashboard_cli.py simulate --webhook $WEBHOOK
```

## 🔧 Troubleshooting

### Common Issues

#### 1. Webhook Not Receiving Alerts
```bash
# Test webhook connectivity
curl -X POST http://localhost:9999/webhook \
  -H "Content-Type: application/json" \
  -d '{"test": "message"}'
```

#### 2. AP Not Found
```bash
# Check available APs
python3 -c "
import json
with open('network_topology.json') as f:
    data = json.load(f)
    aps = [ap['ap_id'] for ap in data['access_points']]
    print('Available APs:', ', '.join(aps))
"
```

#### 3. Incident ID Not Found
```bash  
# List recent incident IDs
python3 -c "
from incident_logger import IncidentLogger
logger = IncidentLogger()
history = logger.get_incident_history(limit=10)
for inc in history:
    print(f'{inc[\"id\"][:8]} - {inc[\"ap_id\"]} - {inc[\"issue_type\"]}')
"
```

## 🎉 Success Verification

Your enhanced CLI is working correctly when you see:

✅ **Commands Execute**: All argparse commands run without errors  
✅ **AP Status Detailed**: Shows all 3 zones with metrics  
✅ **Webhooks Send**: Alerts reach Slack/Discord successfully  
✅ **Replay Works**: Past incidents can be re-run by ID  
✅ **Data Integration**: Uses both JSON files correctly  
✅ **Rich Formatting**: Emojis and colors display properly  

## 🚀 Integration Ready

The enhanced CLI is now ready for:
- **Production monitoring**: Real webhook integrations
- **Automated scripts**: Scheduled incident simulations  
- **Team workflows**: Incident response procedures
- **System integration**: API calls and data exchange
- **Documentation**: Complete command reference available

**Your LiveOpsLab CLI is now feature-complete with webhook alerts! 🎯**
