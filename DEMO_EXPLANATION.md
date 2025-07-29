# LiveOpsLab AI-Powered Incident Management Demo

## Overview
This document provides a comprehensive explanation of the LiveOpsLab system's AI-powered analysis capabilities and how to run the demonstration scripts.

## System Architecture

### Core Components
1. **FastAPI Backend** (`backend/main.py`) - Port 8000
   - AI-powered incident analysis using simulated AWS Bedrock
   - Real-time zone monitoring and incident management
   - Automated recovery and escalation systems

2. **Interactive Dashboard** (`dashboard/index.html`) - Port 3000
   - Real-time venue network status visualization
   - Outage simulation controls
   - Auto-refreshing metrics display

3. **AI Analysis Engine** (`BedrockAnalyzer` class)
   - Simulated AWS Bedrock integration
   - Root cause analysis with confidence scoring
   - Preventive measure recommendations

## AI Analysis Capabilities

### What the AI Analyzes
- **Incident Type**: Network outages, connectivity issues, performance degradation
- **Root Cause Identification**: CPU utilization, network failures, resource contention
- **Confidence Scoring**: 0-100% confidence in analysis
- **Preventive Measures**: Actionable recommendations to prevent recurrence
- **Escalation Requirements**: Automatic escalation based on severity

### Sample AI Output
```
Incident: Network connectivity issue at venue-1
Root Cause: High CPU utilization due to process spike or resource contention
Confidence: 60%
Preventive Measures: Implement CPU monitoring and alerting
Escalation: No
Resolution: Automated recovery initiated
```

## Running the Demonstrations

### Prerequisites
1. Ensure Python virtual environment is activated:
   ```bash
   source .venv/bin/activate
   ```

2. Start the FastAPI backend:
   ```bash
   cd backend && python -m uvicorn main:app --reload --port 8000
   ```

3. Open the dashboard in a browser:
   ```
   http://localhost:3000
   ```

### Demo Script 1: Comprehensive System Demo (`demo.py`)
This script demonstrates the full system capabilities:

```bash
python demo.py
```

**What it shows:**
- System status checks
- Multiple venue outage simulations
- AI analysis for each incident type
- Automated recovery processes
- Real-time monitoring capabilities

### Demo Script 2: AI-Focused Demo (`ai_demo.py`)
This script specifically highlights the AI analysis capabilities:

```bash
python ai_demo.py
```

**What it shows:**
- Detailed AI analysis output
- Root cause identification process
- Confidence scoring mechanisms
- Preventive measure recommendations
- Escalation decision logic

## API Endpoints for Manual Testing

### Core Endpoints
- `GET /` - System health check
- `GET /zones` - View all venue zones and their status
- `POST /simulate-outage` - Trigger outage simulation
- `POST /recover-zone/{zone_id}` - Manual zone recovery
- `GET /analyze-incident` - Get AI analysis for incidents

### Testing AI Analysis
```bash
# Test AI analysis endpoint
curl -X GET "http://localhost:8000/analyze-incident?zone_id=venue-1&incident_type=network"

# Simulate an outage and see AI response
curl -X POST "http://localhost:8000/simulate-outage" \
  -H "Content-Type: application/json" \
  -d '{"zone_id": "venue-1", "incident_type": "network", "duration": 30}'
```

## Understanding the AI Analysis Process

### 1. Incident Detection
- Automatic monitoring detects anomalies
- Zone status changes trigger analysis
- Manual simulation for testing purposes

### 2. Data Collection
- System metrics gathering
- Historical incident patterns
- Network connectivity tests

### 3. AI Analysis Phase
- AWS Bedrock simulation processes incident data
- Root cause analysis algorithms
- Confidence scoring based on available data
- Pattern matching with known issues

### 4. Response Generation
- Preventive measures based on root cause
- Escalation decisions based on severity
- Recovery recommendations
- Documentation for future reference

## Key Features Demonstrated

### Real-Time Monitoring
- Continuous zone health checks
- Automatic status updates
- Performance metric tracking

### AI-Powered Insights
- Intelligent root cause analysis
- Confidence-based decision making
- Preventive measure recommendations

### Automated Recovery
- Self-healing system capabilities
- Escalation workflows
- Manual override options

### Interactive Dashboard
- Visual status representation
- Manual control capabilities  
- Real-time metric updates

## Troubleshooting

### Common Issues
1. **Services not starting**: Ensure virtual environment is activated
2. **Port conflicts**: Check if ports 8000/3000 are available
3. **Module import errors**: Verify PYTHONPATH is set correctly
4. **AI analysis not showing**: Check backend logs for errors

### Verification Steps
1. Backend health: `curl http://localhost:8000/`
2. Zone status: `curl http://localhost:8000/zones`
3. Dashboard access: Open `http://localhost:3000` in browser
4. AI analysis: Run `python ai_demo.py`

## Next Steps for Version 2
This demonstration system provides the foundation for Version 2 development, which could include:
- Real AWS Bedrock integration
- Enhanced ML models
- Additional incident types
- Advanced analytics dashboard
- Production deployment capabilities

The current system successfully demonstrates the core AI-powered incident management concept with simulated cloud services, providing a solid foundation for production implementation.
