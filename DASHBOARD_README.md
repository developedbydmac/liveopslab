# 🌐 LiveOpsLab Network Dashboard

A comprehensive network monitoring dashboard for visualizing and managing 50 access points across multiple zones in real-time.

## 🎯 Features

### Visual Dashboard
- **10x5 Grid Layout**: Displays all 50 access points (AP-01 to AP-50)
- **Color-Coded Status**: Green (healthy), Yellow (warning), Red (down)
- **Three Zones per AP**: FanWiFi, VisitorWiFi, Backstage
- **Real-Time Updates**: Refreshes every 30 seconds
- **Hover Tooltips**: Shows latency, client count, throughput, and last update time
- **Responsive Design**: Works on desktop and mobile devices

### Incident Management
- **Incident Simulation**: Create network incidents for testing
- **Root Cause Analysis**: AI-powered diagnosis with confidence scoring
- **Incident Resolution**: Track and resolve network issues
- **Historical Logging**: Complete incident history with timestamps

### Network Monitoring
- **Live Status**: Real-time network health monitoring
- **Zone Health**: Percentage of healthy APs per zone
- **Switch Mapping**: 17 network switches with 3 APs each
- **Performance Metrics**: Latency, throughput, connected clients

## 🚀 Quick Start

### 1. Generate Network Topology
```bash
# Create the initial network map with 50 APs
python3 generate_network_map.py
```

### 2. Start the Dashboard Server
```bash
# Start the web server on port 8888
python3 dashboard_server.py
```

### 3. Open the Dashboard
Navigate to: `http://localhost:8888`

## 🎮 Using the CLI Tool

### Check Network Status
```bash
python3 dashboard_cli.py status
```

### Simulate an Incident
```bash
# Random incident
python3 dashboard_cli.py simulate

# Specific incident
python3 dashboard_cli.py simulate --ap AP-01 --zone FanWiFi --issue network_connectivity
```

### Resolve an Incident
```bash
python3 dashboard_cli.py resolve <incident-id>
```

### Monitor Network (Real-time)
```bash
python3 dashboard_cli.py monitor --duration 120
```

### Run Demo Scenario
```bash
python3 dashboard_cli.py demo
```

## 📁 Project Structure

```
liveopslab/
├── network_dashboard.html     # Main dashboard interface
├── dashboard_server.py        # HTTP server with API endpoints
├── generate_network_map.py    # Network topology generator
├── dashboard_cli.py           # Command-line interface
├── incident_logger.py         # Core incident management system
├── network_topology.json      # Generated network data
└── incident_log.json          # Incident history (auto-created)
```

## 🎨 Dashboard Interface

### Status Overview
- **Total APs**: 50 access points
- **Healthy Zones**: Count and percentage
- **Warning Zones**: Performance issues
- **Down Zones**: Critical failures

### AP Grid Display
Each AP tile shows:
- **AP ID**: AP-01 through AP-50
- **Three Status Dots**: One for each zone
- **Zone Labels**: Fan, Visit, Back

### Tooltip Information
Hover over any status dot to see:
- AP ID and Zone name
- Current status (Healthy/Warning/Down)
- Latency in milliseconds
- Connected client count
- Throughput in Mbps
- Last update timestamp

## 🔧 API Endpoints

### GET /network_topology.json
Returns complete network topology data:
```json
{
  "metadata": {
    "generated_at": "2025-07-29T...",
    "total_access_points": 50,
    "total_switches": 17
  },
  "access_points": [...],
  "switches": {...}
}
```

### GET /api/simulate_incident
Simulates a random network incident:
```json
{
  "incident_id": "uuid",
  "status": "incident_simulated",
  "message": "Simulated power_failure incident for AP-15 zone Backstage",
  "incident_details": {...},
  "zone_health_snapshot": {...}
}
```

## 🏗️ Network Architecture

### Access Points
- **50 APs total**: AP-01 to AP-50
- **4 floors**: ~12-13 APs per floor
- **4 sections**: North, South, East, West
- **3 zones each**: FanWiFi, VisitorWiFi, Backstage

### Network Switches
- **17 switches**: Switch-01 to Switch-17
- **~3 APs per switch**: Distributed load
- **PoE power budget**: 740W per switch
- **48 ports each**: Enterprise-grade switching

### Hardware Models
- Cisco Catalyst 9130AXI
- Aruba AP-535
- Ubiquiti UniFi 6 Enterprise
- Ruckus R750

## 🎯 Zone Types

### FanWiFi
- **Purpose**: General fan internet access
- **Capacity**: Up to 75 clients per AP
- **Performance**: Variable based on crowd density

### VisitorWiFi
- **Purpose**: Visitor and guest access
- **Capacity**: Up to 50 clients per AP
- **Performance**: Moderate with content filtering

### Backstage
- **Purpose**: Staff and operational use
- **Capacity**: Up to 15 clients per AP
- **Performance**: High priority, low latency

## 🔍 Root Cause Analysis

The system provides intelligent diagnosis for 5 issue types:

### 1. Network Connectivity
- Signal degradation, cable issues, switch problems
- **Confidence**: 65-85%
- **Recovery**: 30-180 seconds

### 2. Power Failure
- PoE budget issues, power supply problems
- **Confidence**: 85-95%
- **Recovery**: 60-300 seconds

### 3. Hardware Malfunction
- Radio failures, memory corruption, antenna issues
- **Confidence**: 50-70%
- **Recovery**: 120-600 seconds

### 4. High Latency
- RF interference, channel congestion, CPU overload
- **Confidence**: 55-75%
- **Recovery**: 45-240 seconds

### 5. Authentication Failure
- RADIUS issues, certificate problems, AD sync
- **Confidence**: 70-90%
- **Recovery**: 90-420 seconds

## 📊 Monitoring Metrics

### Performance Indicators
- **Latency**: < 50ms (healthy), 50-100ms (warning), >100ms (down)
- **Throughput**: Real-time bandwidth utilization
- **Client Count**: Connected devices per zone
- **Signal Strength**: RF signal quality in dBm

### Health Scoring
- **Green (Healthy)**: Normal operation, latency under 50ms
- **Yellow (Warning)**: Performance degraded, needs attention
- **Red (Down)**: Critical failure, immediate action required

## 🎛️ Dashboard Controls

### Auto-Refresh
- **Interval**: 30 seconds
- **Status Indicator**: Shows last update time
- **Visual Feedback**: Pulse animation during updates

### Interactive Elements
- **Hover Effects**: Smooth transitions and scaling
- **Tooltip Display**: Rich information on demand
- **Mobile Responsive**: Touch-friendly interface

## 🚨 Incident Workflow

### 1. Detection
- Automated monitoring detects issues
- Status changes from healthy to warning/down
- Visual indicators update in real-time

### 2. Analysis
- Root cause analysis runs automatically
- Contextual diagnosis based on location/hardware
- Confidence scoring and recovery estimates

### 3. Resolution
- Step-by-step troubleshooting guides
- Fix suggestions based on issue type
- Automated status restoration

### 4. Logging
- Complete incident history
- UUID-based incident tracking
- JSON-formatted logs for integration

## 🔧 Customization

### Styling
Edit `network_dashboard.html` CSS section:
- Colors: Modify `.dot.healthy`, `.dot.warning`, `.dot.down`
- Layout: Adjust `.network-grid` columns
- Animations: Update transition durations

### Data Sources
Modify `dashboard_server.py`:
- Change refresh intervals
- Add custom metrics
- Integrate with existing monitoring systems

### Issue Types
Extend `incident_logger.py`:
- Add new issue categories
- Customize root cause templates
- Adjust confidence algorithms

## 🎉 Demo Features

### Visual Highlights
- **Dark Theme**: Professional monitoring aesthetic
- **Neon Accents**: Cyan highlights for modern look
- **Smooth Animations**: Hover effects and transitions
- **Status Cards**: Summary metrics at the top

### Real-Time Updates
- **Live Data**: Updates every 30 seconds
- **Mock Data**: Realistic simulation when topology file missing
- **Status Changes**: Visual feedback for all state changes

### Interactive Tooltips
- **Rich Information**: Detailed AP and zone data
- **Smart Positioning**: Avoids screen edges
- **Smooth Transitions**: Fade in/out effects

## 📈 Future Enhancements

### Planned Features
- Historical trend charts
- Alert notifications
- Performance analytics
- Custom dashboard layouts
- Integration with external monitoring tools

### API Extensions
- WebSocket real-time updates
- Bulk incident operations
- Custom metric endpoints
- Authentication and authorization

## 🤝 Integration

### With Existing Systems
- REST API endpoints for data exchange
- JSON format for easy parsing
- Standard HTTP server for compatibility
- Modular design for custom extensions

### Export Options
- Network topology as JSON
- Incident logs as JSON
- Performance metrics via API
- Dashboard screenshots (manual)

---

## 🚀 Getting Started Checklist

- [ ] Run `python3 generate_network_map.py`
- [ ] Start `python3 dashboard_server.py`
- [ ] Open `http://localhost:8888` in browser
- [ ] Test with `python3 dashboard_cli.py demo`
- [ ] Explore the interactive dashboard
- [ ] Simulate incidents and watch real-time updates

**Enjoy monitoring your LiveOpsLab network! 🎉**
