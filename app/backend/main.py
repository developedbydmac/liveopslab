#!/usr/bin/env python3
"""
LiveOpsLab FastAPI Backend
Incident Management and AI-Powered Root Cause Analysis
"""

import os
import json
import asyncio
import logging
import uuid
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, asdict
from enum import Enum

import boto3
import httpx
from fastapi import FastAPI, HTTPException, BackgroundTasks, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from botocore.exceptions import ClientError

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="LiveOpsLab Incident Management API",
    description="AI-powered incident management for venue network infrastructure",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Enable CORS for dashboard
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Enums and Models
class ZoneStatus(str, Enum):
    HEALTHY = "healthy"
    DEGRADED = "degraded"
    OUTAGE = "outage"
    MAINTENANCE = "maintenance"

class IncidentSeverity(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"

class OutageType(str, Enum):
    NETWORK_FAILURE = "network_failure"
    HIGH_LATENCY = "high_latency"
    CPU_SPIKE = "cpu_spike"
    MEMORY_EXHAUSTION = "memory_exhaustion"
    DISK_FULL = "disk_full"
    SERVICE_UNAVAILABLE = "service_unavailable"

@dataclass
class ZoneInfo:
    name: str
    status: ZoneStatus
    last_updated: datetime
    uptime_percentage: float
    active_users: int
    avg_latency_ms: float
    cpu_usage: float
    memory_usage: float
    disk_usage: float
    network_throughput_mbps: float

@dataclass
class Incident:
    id: str
    zone: str
    outage_type: OutageType
    severity: IncidentSeverity
    start_time: datetime
    end_time: Optional[datetime]
    duration_seconds: Optional[int]
    affected_users: int
    description: str
    root_cause: Optional[str]
    recommended_fix: Optional[str]
    ai_analysis: Optional[Dict[str, Any]]
    logs: List[str]
    status: str  # "active", "resolved", "investigating"

# Request/Response Models
class SimulateOutageRequest(BaseModel):
    outage_type: OutageType
    duration_seconds: int = Field(default=300, ge=30, le=3600)
    severity: IncidentSeverity = IncidentSeverity.MEDIUM
    description: str = ""

class OutageResponse(BaseModel):
    incident_id: str
    zone: str
    message: str
    estimated_duration: int

class ZoneStatusResponse(BaseModel):
    zone: str
    status: ZoneStatus
    uptime_percentage: float
    active_users: int
    avg_latency_ms: float
    cpu_usage: float
    memory_usage: float
    disk_usage: float
    network_throughput_mbps: float
    last_updated: str
    current_incidents: List[str]

class IncidentReplayResponse(BaseModel):
    incident: Dict[str, Any]
    ai_analysis: Dict[str, Any]
    timeline: List[Dict[str, Any]]
    lessons_learned: List[str]

# Global state management
class StateManager:
    def __init__(self):
        self.zones = {
            "FanWiFi": ZoneInfo(
                name="FanWiFi",
                status=ZoneStatus.HEALTHY,
                last_updated=datetime.utcnow(),
                uptime_percentage=99.5,
                active_users=245,
                avg_latency_ms=15.2,
                cpu_usage=25.0,
                memory_usage=45.0,
                disk_usage=60.0,
                network_throughput_mbps=125.3
            ),
            "VisitorWiFi": ZoneInfo(
                name="VisitorWiFi",
                status=ZoneStatus.HEALTHY,
                last_updated=datetime.utcnow(),
                uptime_percentage=99.8,
                active_users=18,
                avg_latency_ms=8.5,
                cpu_usage=15.0,
                memory_usage=35.0,
                disk_usage=40.0,
                network_throughput_mbps=85.7
            ),
            "Backstage": ZoneInfo(
                name="Backstage",
                status=ZoneStatus.HEALTHY,
                last_updated=datetime.utcnow(),
                uptime_percentage=99.9,
                active_users=3,
                avg_latency_ms=5.2,
                cpu_usage=35.0,
                memory_usage=55.0,
                disk_usage=70.0,
                network_throughput_mbps=45.8
            )
        }
        self.incidents: Dict[str, Incident] = {}
        self.active_outages: Dict[str, str] = {}  # zone -> incident_id

    def get_zone(self, zone_name: str) -> ZoneInfo:
        if zone_name not in self.zones:
            raise ValueError(f"Unknown zone: {zone_name}")
        return self.zones[zone_name]

    def update_zone_status(self, zone_name: str, status: ZoneStatus, metrics: Dict[str, float] = None):
        zone = self.get_zone(zone_name)
        zone.status = status
        zone.last_updated = datetime.utcnow()
        
        if metrics:
            for key, value in metrics.items():
                if hasattr(zone, key):
                    setattr(zone, key, value)

    def create_incident(self, zone: str, outage_type: OutageType, severity: IncidentSeverity, 
                       duration_seconds: int, description: str) -> str:
        incident_id = str(uuid.uuid4())
        
        incident = Incident(
            id=incident_id,
            zone=zone,
            outage_type=outage_type,
            severity=severity,
            start_time=datetime.utcnow(),
            end_time=None,
            duration_seconds=duration_seconds,
            affected_users=self.zones[zone].active_users,
            description=description or f"{outage_type.value} in {zone}",
            root_cause=None,
            recommended_fix=None,
            ai_analysis=None,
            logs=[],
            status="active"
        )
        
        self.incidents[incident_id] = incident
        self.active_outages[zone] = incident_id
        
        return incident_id

    def resolve_incident(self, incident_id: str):
        if incident_id in self.incidents:
            incident = self.incidents[incident_id]
            incident.end_time = datetime.utcnow()
            incident.status = "resolved"
            incident.duration_seconds = int((incident.end_time - incident.start_time).total_seconds())
            
            # Remove from active outages
            if incident.zone in self.active_outages:
                del self.active_outages[incident.zone]

state_manager = StateManager()

# AWS Bedrock client
class BedrockAnalyzer:
    def __init__(self):
        try:
            self.bedrock = boto3.client(
                'bedrock-runtime',
                region_name=os.getenv('AWS_REGION', 'us-east-1')
            )
            self.model_id = 'anthropic.claude-3-sonnet-20240229-v1:0'
        except Exception as e:
            logger.warning(f"Bedrock client initialization failed: {e}")
            self.bedrock = None

    async def analyze_incident(self, incident: Incident, zone_metrics: Dict, logs: List[str]) -> Dict[str, Any]:
        """Use Bedrock Claude to analyze incident and suggest root cause"""
        if not self.bedrock:
            return self._fallback_analysis(incident)

        try:
            # Prepare prompt with incident data
            prompt = self._build_analysis_prompt(incident, zone_metrics, logs)
            
            # Call Claude via Bedrock
            response = self.bedrock.invoke_model(
                modelId=self.model_id,
                body=json.dumps({
                    "anthropic_version": "bedrock-2023-05-31",
                    "max_tokens": 1000,
                    "messages": [
                        {
                            "role": "user",
                            "content": prompt
                        }
                    ]
                })
            )
            
            response_body = json.loads(response['body'].read())
            analysis_text = response_body['content'][0]['text']
            
            # Parse structured response
            return self._parse_ai_response(analysis_text)
            
        except Exception as e:
            logger.error(f"Bedrock analysis failed: {e}")
            return self._fallback_analysis(incident)

    def _build_analysis_prompt(self, incident: Incident, zone_metrics: Dict, logs: List[str]) -> str:
        logs_text = "\n".join(logs[-10:]) if logs else "No recent logs available"
        
        return f"""
You are an expert SRE analyzing a network infrastructure incident. Please analyze the following incident data and provide a structured response.

INCIDENT DETAILS:
- Zone: {incident.zone}
- Type: {incident.outage_type.value}
- Severity: {incident.severity.value}
- Start Time: {incident.start_time}
- Duration: {incident.duration_seconds}s
- Affected Users: {incident.affected_users}
- Description: {incident.description}

CURRENT METRICS:
{json.dumps(zone_metrics, indent=2)}

RECENT LOGS:
{logs_text}

Please provide your analysis in the following JSON format:
{{
    "root_cause": "Most likely root cause explanation",
    "confidence_level": 0.85,
    "recommended_fix": "Specific action to resolve the issue",
    "preventive_measures": ["List of measures to prevent recurrence"],
    "escalation_needed": false,
    "estimated_recovery_time": "5-10 minutes",
    "similar_incidents": ["Any patterns with previous incidents"],
    "monitoring_gaps": ["What monitoring could have caught this earlier"]
}}

Focus on actionable insights based on the venue network context (FanWiFi, VisitorWiFi, Backstage zones).
"""

    def _parse_ai_response(self, response_text: str) -> Dict[str, Any]:
        """Parse AI response and extract structured data"""
        try:
            # Look for JSON in the response
            import re
            json_match = re.search(r'\{.*\}', response_text, re.DOTALL)
            if json_match:
                return json.loads(json_match.group())
        except:
            pass
        
        # Fallback to parsing key information
        return {
            "root_cause": "AI analysis parsing failed - manual review needed",
            "confidence_level": 0.3,
            "recommended_fix": response_text[:200] + "..." if len(response_text) > 200 else response_text,
            "preventive_measures": ["Review AI analysis manually"],
            "escalation_needed": True,
            "estimated_recovery_time": "Unknown",
            "similar_incidents": [],
            "monitoring_gaps": ["AI analysis system needs attention"]
        }

    def _fallback_analysis(self, incident: Incident) -> Dict[str, Any]:
        """Fallback analysis when Bedrock is unavailable"""
        fallback_analyses = {
            OutageType.NETWORK_FAILURE: {
                "root_cause": "Network interface failure or connectivity issue",
                "recommended_fix": "Restart network services, check physical connections",
                "preventive_measures": ["Implement redundant network paths", "Add network monitoring"],
                "estimated_recovery_time": "2-5 minutes"
            },
            OutageType.HIGH_LATENCY: {
                "root_cause": "Network congestion or routing issues",
                "recommended_fix": "Check bandwidth utilization, optimize routing",
                "preventive_measures": ["Implement QoS policies", "Monitor bandwidth usage"],
                "estimated_recovery_time": "5-15 minutes"
            },
            OutageType.CPU_SPIKE: {
                "root_cause": "High CPU utilization due to process spike or resource contention",
                "recommended_fix": "Identify and terminate resource-intensive processes",
                "preventive_measures": ["Set CPU limits", "Implement auto-scaling"],
                "estimated_recovery_time": "1-3 minutes"
            }
        }
        
        analysis = fallback_analyses.get(incident.outage_type, {
            "root_cause": "Unknown - requires manual investigation",
            "recommended_fix": "Investigate logs and metrics manually",
            "preventive_measures": ["Improve monitoring coverage"],
            "estimated_recovery_time": "Unknown"
        })
        
        return {
            **analysis,
            "confidence_level": 0.6,
            "escalation_needed": incident.severity in [IncidentSeverity.HIGH, IncidentSeverity.CRITICAL],
            "similar_incidents": [],
            "monitoring_gaps": ["AI analysis unavailable - using fallback logic"]
        }

bedrock_analyzer = BedrockAnalyzer()

# API Endpoints
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "version": "1.0.0",
        "zones_monitored": len(state_manager.zones),
        "active_incidents": len(state_manager.active_outages)
    }

@app.post("/simulate-outage/{zone}", response_model=OutageResponse)
async def simulate_outage(
    zone: str, 
    request: SimulateOutageRequest,
    background_tasks: BackgroundTasks
):
    """Simulate an outage in the specified zone"""
    if zone not in state_manager.zones:
        raise HTTPException(status_code=404, detail=f"Zone '{zone}' not found")
    
    if zone in state_manager.active_outages:
        raise HTTPException(
            status_code=409, 
            detail=f"Zone '{zone}' already has an active outage: {state_manager.active_outages[zone]}"
        )
    
    # Create incident
    incident_id = state_manager.create_incident(
        zone=zone,
        outage_type=request.outage_type,
        severity=request.severity,
        duration_seconds=request.duration_seconds,
        description=request.description
    )
    
    # Update zone status based on outage type
    if request.outage_type == OutageType.NETWORK_FAILURE:
        status = ZoneStatus.OUTAGE
        metrics = {"avg_latency_ms": 999.0, "network_throughput_mbps": 0.0}
    elif request.outage_type == OutageType.HIGH_LATENCY:
        status = ZoneStatus.DEGRADED
        metrics = {"avg_latency_ms": 250.0, "network_throughput_mbps": 10.0}
    elif request.outage_type == OutageType.CPU_SPIKE:
        status = ZoneStatus.DEGRADED
        metrics = {"cpu_usage": 95.0, "avg_latency_ms": 150.0}
    else:
        status = ZoneStatus.DEGRADED
        metrics = {}
    
    state_manager.update_zone_status(zone, status, metrics)
    
    # Schedule recovery
    background_tasks.add_task(schedule_recovery, incident_id, request.duration_seconds)
    
    # Schedule AI analysis
    background_tasks.add_task(analyze_incident_async, incident_id)
    
    logger.info(f"Simulated {request.outage_type.value} outage in {zone} for {request.duration_seconds}s")
    
    return OutageResponse(
        incident_id=incident_id,
        zone=zone,
        message=f"Simulated {request.outage_type.value} outage started",
        estimated_duration=request.duration_seconds
    )

@app.get("/status/{zone}", response_model=ZoneStatusResponse)
async def get_zone_status(zone: str):
    """Get current status of a specific zone"""
    if zone not in state_manager.zones:
        raise HTTPException(status_code=404, detail=f"Zone '{zone}' not found")
    
    zone_info = state_manager.zones[zone]
    active_incidents = [
        incident_id for incident_id in state_manager.active_outages.values()
        if state_manager.incidents[incident_id].zone == zone
    ]
    
    return ZoneStatusResponse(
        zone=zone_info.name,
        status=zone_info.status,
        uptime_percentage=zone_info.uptime_percentage,
        active_users=zone_info.active_users,
        avg_latency_ms=zone_info.avg_latency_ms,
        cpu_usage=zone_info.cpu_usage,
        memory_usage=zone_info.memory_usage,
        disk_usage=zone_info.disk_usage,
        network_throughput_mbps=zone_info.network_throughput_mbps,
        last_updated=zone_info.last_updated.isoformat(),
        current_incidents=active_incidents
    )

@app.get("/status")
async def get_all_zones_status():
    """Get status of all zones"""
    zones_status = {}
    for zone_name in state_manager.zones:
        zone_info = state_manager.zones[zone_name]
        active_incidents = [
            incident_id for incident_id in state_manager.active_outages.values()
            if state_manager.incidents[incident_id].zone == zone_name
        ]
        
        zones_status[zone_name] = {
            "status": zone_info.status.value,
            "uptime_percentage": zone_info.uptime_percentage,
            "active_users": zone_info.active_users,
            "avg_latency_ms": zone_info.avg_latency_ms,
            "cpu_usage": zone_info.cpu_usage,
            "memory_usage": zone_info.memory_usage,
            "disk_usage": zone_info.disk_usage,
            "network_throughput_mbps": zone_info.network_throughput_mbps,
            "last_updated": zone_info.last_updated.isoformat(),
            "current_incidents": active_incidents
        }
    
    return {
        "timestamp": datetime.utcnow().isoformat(),
        "zones": zones_status,
        "total_active_incidents": len(state_manager.active_outages)
    }

@app.get("/replay/{incident_id}", response_model=IncidentReplayResponse)
async def replay_incident(incident_id: str):
    """Replay and analyze a specific incident"""
    if incident_id not in state_manager.incidents:
        raise HTTPException(status_code=404, detail=f"Incident '{incident_id}' not found")
    
    incident = state_manager.incidents[incident_id]
    
    # Generate timeline
    timeline = [
        {
            "timestamp": incident.start_time.isoformat(),
            "event": "Incident Started",
            "details": f"{incident.outage_type.value} detected in {incident.zone}",
            "severity": incident.severity.value
        }
    ]
    
    if incident.ai_analysis:
        timeline.append({
            "timestamp": (incident.start_time + timedelta(seconds=30)).isoformat(),
            "event": "AI Analysis Completed",
            "details": f"Root cause identified: {incident.ai_analysis.get('root_cause', 'Unknown')}",
            "confidence": incident.ai_analysis.get('confidence_level', 0.0)
        })
    
    if incident.end_time:
        timeline.append({
            "timestamp": incident.end_time.isoformat(),
            "event": "Incident Resolved",
            "details": f"Service restored after {incident.duration_seconds}s",
            "recovery_time": incident.duration_seconds
        })
    
    # Lessons learned
    lessons_learned = []
    if incident.ai_analysis:
        lessons_learned.extend(incident.ai_analysis.get('preventive_measures', []))
        lessons_learned.extend(incident.ai_analysis.get('monitoring_gaps', []))
    
    return IncidentReplayResponse(
        incident=asdict(incident),
        ai_analysis=incident.ai_analysis or {},
        timeline=timeline,
        lessons_learned=lessons_learned
    )

@app.get("/incidents")
async def list_incidents(
    zone: Optional[str] = None,
    status: Optional[str] = None,
    limit: int = 50
):
    """List incidents with optional filtering"""
    incidents = list(state_manager.incidents.values())
    
    # Apply filters
    if zone:
        incidents = [i for i in incidents if i.zone == zone]
    if status:
        incidents = [i for i in incidents if i.status == status]
    
    # Sort by start time (most recent first)
    incidents.sort(key=lambda x: x.start_time, reverse=True)
    
    # Limit results
    incidents = incidents[:limit]
    
    return {
        "incidents": [asdict(incident) for incident in incidents],
        "total": len(incidents)
    }

# Background tasks
async def schedule_recovery(incident_id: str, duration_seconds: int):
    """Schedule incident recovery after specified duration"""
    await asyncio.sleep(duration_seconds)
    
    if incident_id in state_manager.incidents:
        incident = state_manager.incidents[incident_id]
        zone = incident.zone
        
        # Restore zone to healthy status
        state_manager.update_zone_status(zone, ZoneStatus.HEALTHY, {
            "avg_latency_ms": 15.0,
            "cpu_usage": 25.0,
            "network_throughput_mbps": 100.0
        })
        
        # Resolve incident
        state_manager.resolve_incident(incident_id)
        
        logger.info(f"Auto-recovered incident {incident_id} in zone {zone}")

async def analyze_incident_async(incident_id: str):
    """Perform AI analysis of incident in background"""
    if incident_id not in state_manager.incidents:
        return
    
    incident = state_manager.incidents[incident_id]
    zone_info = state_manager.zones[incident.zone]
    
    # Simulate getting logs (in real implementation, fetch from CloudWatch/S3)
    mock_logs = [
        f"[{datetime.utcnow().isoformat()}] ERROR: {incident.outage_type.value} detected in {incident.zone}",
        f"[{datetime.utcnow().isoformat()}] WARN: Latency increased to {zone_info.avg_latency_ms}ms",
        f"[{datetime.utcnow().isoformat()}] INFO: {zone_info.active_users} users affected"
    ]
    
    zone_metrics = asdict(zone_info)
    
    # Perform AI analysis
    analysis = await bedrock_analyzer.analyze_incident(incident, zone_metrics, mock_logs)
    
    # Update incident with analysis
    incident.ai_analysis = analysis
    incident.root_cause = analysis.get('root_cause')
    incident.recommended_fix = analysis.get('recommended_fix')
    incident.logs = mock_logs
    
    logger.info(f"AI analysis completed for incident {incident_id}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
