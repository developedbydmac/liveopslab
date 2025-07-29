# 🚨 LiveOpsLab Enhanced Incident Management API v2.0

## Overview
The enhanced incident management system provides intelligent root cause analysis for network incidents across 50 access points and 20 switches. The system combines incident simulation, logging, and AI-powered diagnostics to deliver actionable insights for network operations.

## 🔍 Root Cause Analysis Function

### `generate_root_cause(ap_id, zone, issue_type)`

**Purpose**: Analyze incidents and provide intelligent diagnostics with fix suggestions.

**Parameters**:
- `ap_id` (string): Access Point ID (e.g., "AP-01")
- `zone` (string): Zone name (FanWiFi, VisitorWiFi, Backstage)  
- `issue_type` (string): Type of issue (network_connectivity, power_failure, etc.)

**Returns**: Complete JSON response with:
- `root_cause`: Identified cause (e.g., "Signal degradation due to interference")
- `fix_suggestion`: Actionable solution (e.g., "Restart AP", "Reboot switch")
- `estimated_recovery_seconds`: Recovery time estimate (30-600 seconds)
- `confidence_level`: Diagnostic confidence (50-95%)
- `troubleshooting_steps`: Step-by-step repair instructions
- `additional_context`: Environmental and historical factors

## 🌐 API Endpoints

### 1. **POST /simulate** - Enhanced Incident Simulation
```bash
curl -X POST "http://localhost:8000/simulate" \
  -H "Content-Type: application/json" \
  -d '{
    "ap_id": "AP-01",
    "zone": "FanWiFi",
    "issue_type": "network_connectivity",
    "include_root_cause": true
  }'
```

**Response**:
```json
{
  "success": true,
  "incident_id": "uuid-here",
  "status": "incident_simulated",
  "message": "Simulated network_connectivity incident for AP-01 zone FanWiFi",
  "incident_details": {
    "id": "uuid-here",
    "timestamp": "2025-07-29T14:30:00.000000",
    "ap_id": "AP-01",
    "zone": "FanWiFi",
    "issue_type": "network_connectivity",
    "status": "down",
    "switch_id": "Switch-01",
    "location": {...},
    "resolved": false
  },
  "zone_health_snapshot": {
    "zone": "FanWiFi",
    "total_aps": 50,
    "healthy_aps": 49,
    "down_aps": 1,
    "health_percentage": 98.0,
    "affected_aps": [...]
  },
  "root_cause_analysis": {
    "root_cause": "Signal degradation due to interference",
    "fix_suggestion": "Restart access point to refresh network stack",
    "estimated_recovery_seconds": 76,
    "confidence_level": 85,
    "troubleshooting_steps": [
      "1. Access AP-01 management interface via SSH or web GUI",
      "2. Check system logs for error messages related to network_connectivity",
      "3. Verify network connectivity to Switch-01",
      "..."
    ],
    "additional_context": {
      "environmental_factors": ["High floor - potential signal interference"],
      "historical_patterns": ["Similar incidents reported during peak hours"],
      "network_topology": {
        "switch_load": "Normal",
        "adjacent_aps": "Operational",
        "backhaul_status": "Healthy"
      }
    }
  }
}
```

### 2. **POST /analyze-root-cause** - Standalone Analysis
```bash
curl -X POST "http://localhost:8000/analyze-root-cause" \
  -H "Content-Type: application/json" \
  -d '{
    "ap_id": "AP-12",
    "zone": "Backstage",
    "issue_type": "power_failure"
  }'
```

**Response**:
```json
{
  "success": true,
  "analysis": {
    "ap_id": "AP-12",
    "zone": "Backstage",
    "issue_type": "power_failure",
    "switch_id": "Switch-03",
    "location": {"floor": 1, "section": "East"},
    "hardware_model": "Ubiquiti UAP-AC-HD",
    "root_cause": "Power budget exceeded on PoE switch",
    "fix_suggestion": "Check PoE power budget and redistribute load",
    "estimated_recovery_seconds": 207,
    "confidence_level": 95,
    "troubleshooting_steps": [...]
  }
}
```

### 3. **GET /incidents/{incident_id}/root-cause** - Incident Analysis
```bash
curl -X GET "http://localhost:8000/incidents/12345678-1234-1234-1234-123456789012/root-cause"
```

### 4. **GET /diagnostics/issue-types** - Supported Issue Types
```bash
curl -X GET "http://localhost:8000/diagnostics/issue-types"
```

**Response**:
```json
{
  "success": true,
  "supported_issue_types": {
    "network_connectivity": {
      "description": "Network connection and communication failures",
      "typical_causes": [
        "Signal degradation due to interference",
        "Network cable disconnection or damage",
        "Switch port failure or configuration issue"
      ],
      "recovery_time_range": "30-180 seconds"
    },
    "power_failure": {
      "description": "Power supply and PoE delivery issues",
      "typical_causes": [
        "Power budget exceeded on PoE switch",
        "Faulty PoE injector or power adapter"
      ],
      "recovery_time_range": "60-300 seconds"
    }
  }
}
```

## 🎯 Root Cause Analysis Features

### **Intelligent Diagnosis**
- **Context-Aware**: Considers AP location, hardware model, switch assignment
- **Issue-Specific**: Tailored analysis for each problem type
- **Confidence Scoring**: 50-95% confidence levels based on available data

### **Actionable Solutions**
- **Fix Suggestions**: Specific repair actions (restart, reboot, replace)
- **Recovery Estimates**: Realistic timeframes (30s-10min) based on issue complexity
- **Priority Adjustment**: Backstage zones get 30% faster recovery estimates

### **Comprehensive Context**
- **Environmental Factors**: Floor level, section location, interference sources
- **Historical Patterns**: Previous incident types, uptime analysis
- **Network Topology**: Switch load, adjacent AP status, backhaul health

### **Troubleshooting Steps**
1. **Access Management**: SSH/web interface instructions
2. **Log Analysis**: Specific log locations and error patterns
3. **Connectivity Tests**: Network verification procedures
4. **Issue-Specific Steps**: Tailored for each problem type
5. **Recovery Actions**: Execute the recommended fix
6. **Monitoring**: Post-fix stability verification

## 🔧 Issue Types Supported

| Issue Type | Description | Typical Recovery Time | Confidence |
|------------|-------------|----------------------|------------|
| `network_connectivity` | Connection failures | 30-180 seconds | 75% |
| `power_failure` | PoE/power issues | 60-300 seconds | 85% |
| `hardware_malfunction` | Physical failures | 120-600 seconds | 70% |
| `high_latency` | Performance issues | 45-240 seconds | 65% |
| `authentication_failure` | Auth system problems | 90-420 seconds | 80% |

## 📊 Example Root Cause Analysis Output

```json
{
  "ap_id": "AP-01",
  "zone": "FanWiFi", 
  "issue_type": "network_connectivity",
  "root_cause": "Signal degradation due to interference",
  "fix_suggestion": "Restart access point to refresh network stack",
  "estimated_recovery_seconds": 76,
  "confidence_level": 85,
  "additional_context": {
    "environmental_factors": ["High floor - potential signal interference"],
    "historical_patterns": ["Similar incidents reported during peak hours"],
    "network_topology": {
      "switch_load": "Normal",
      "adjacent_aps": "Operational", 
      "backhaul_status": "Healthy"
    }
  },
  "troubleshooting_steps": [
    "1. Access AP-01 management interface via SSH or web GUI",
    "2. Check system logs for error messages related to network_connectivity",
    "3. Verify network connectivity to Switch-01",
    "4. Test ping connectivity to gateway and DNS servers",
    "5. Check interface statistics for packet drops or errors",
    "6. Verify VLAN configuration and port settings",
    "7. Execute fix: Restart access point to refresh network stack",
    "8. Monitor system for 5-10 minutes to confirm stability",
    "9. Update incident log with resolution details"
  ]
}
```

## 🚀 Integration Instructions

### **1. Backend Integration**
```python
from incident_logger import IncidentLogger

# Initialize logger
incident_logger = IncidentLogger()

# Generate root cause analysis
analysis = incident_logger.generate_root_cause(
    ap_id="AP-01",
    zone="FanWiFi", 
    issue_type="network_connectivity"
)
```

### **2. FastAPI Routes**
```python
from enhanced_incident_api import add_enhanced_incident_routes

# Add to existing FastAPI app
add_enhanced_incident_routes(app)
```

### **3. Required Files**
- `incident_logger.py` - Core analysis engine
- `network_topology.json` - 50 APs + 20 switches data
- `incident_log.json` - UUID-based incident logging

## ✅ System Status

**Infrastructure**: ✅ 50 Access Points + 20 Switches  
**Root Cause Engine**: ✅ 5 Issue Types Supported  
**API Integration**: ✅ 7 Enhanced Endpoints  
**Logging System**: ✅ UUID-based Incident Tracking  
**Testing**: ✅ Comprehensive Test Coverage  

The enhanced incident management system is fully operational and ready for production deployment! 🎉
