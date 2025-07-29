#!/usr/bin/env python3
"""
Complete FastAPI integration for LiveOpsLab incident management.
Add these routes to your existing backend/main.py file.
"""

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from typing import Dict, List, Any, Optional
from datetime import datetime
import uuid

# Import the incident logger (make sure this path is correct in your backend)
from incident_logger import IncidentLogger

# Initialize global incident logger
incident_logger = IncidentLogger()

# Pydantic models for requests/responses
class IncidentSimulationRequest(BaseModel):
    ap_id: str = Field(..., description="Access Point ID (e.g., 'AP-01')", example="AP-01")
    zone: str = Field(..., description="Zone name", example="FanWiFi")
    issue_type: str = Field(..., description="Type of issue", example="network_connectivity")

class IncidentResolutionRequest(BaseModel):
    incident_id: str = Field(..., description="UUID of incident to resolve")

class IncidentResponse(BaseModel):
    success: bool
    incident_id: str
    status: str
    message: str
    incident_details: Dict[str, Any]
    zone_health_snapshot: Dict[str, Any]
    timestamp: str

class ResolutionResponse(BaseModel):
    success: bool
    status: str
    message: str
    incident_id: Optional[str] = None
    resolution_timestamp: Optional[str] = None
    timestamp: str

# === ADD THESE ROUTES TO YOUR EXISTING FASTAPI APP ===

def add_incident_routes(app: FastAPI):
    """
    Add incident management routes to existing FastAPI app.
    Call this function in your main.py after creating the FastAPI app.
    """
    
    @app.post("/simulate", response_model=IncidentResponse, tags=["Incident Management"])
    async def simulate_incident(request: IncidentSimulationRequest):
        """
        🚨 **Simulate Network Incident**
        
        Simulates an incident by:
        - Updating the specified zone status to "down" 
        - Logging the incident with UUID and timestamp
        - Returning zone health snapshot
        
        **Supported Issue Types:**
        - `network_connectivity` - Network connection issues
        - `power_failure` - Power supply problems  
        - `hardware_malfunction` - Hardware failures
        - `high_latency` - Performance degradation
        - `authentication_failure` - Auth system issues
        """
        try:
            result = incident_logger.simulate_incident(
                ap_id=request.ap_id,
                zone=request.zone,
                issue_type=request.issue_type
            )
            
            return IncidentResponse(
                success=True,
                incident_id=result["incident_id"],
                status=result["status"],
                message=result["message"],
                incident_details=result["incident_details"],
                zone_health_snapshot=result["zone_health_snapshot"],
                timestamp=datetime.now().isoformat()
            )
            
        except ValueError as e:
            raise HTTPException(status_code=404, detail=str(e))
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")
    
    @app.post("/resolve-incident", response_model=ResolutionResponse, tags=["Incident Management"])
    async def resolve_incident(request: IncidentResolutionRequest):
        """
        🔧 **Resolve Active Incident**
        
        Resolves an incident by:
        - Restoring zone status to "healthy"
        - Updating incident log with resolution timestamp
        - Restoring realistic network metrics
        """
        try:
            result = incident_logger.resolve_incident(request.incident_id)
            
            return ResolutionResponse(
                success=True,
                status=result["status"],
                message=result["message"],
                incident_id=result.get("incident_id"),
                resolution_timestamp=result.get("resolution_timestamp"),
                timestamp=datetime.now().isoformat()
            )
            
        except ValueError as e:
            raise HTTPException(status_code=404, detail=str(e))
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")
    
    @app.get("/incidents/active", tags=["Incident Management"])
    async def get_active_incidents():
        """
        🔥 **Get Active Incidents**
        
        Returns all currently unresolved incidents with details:
        - Incident ID and timestamp
        - Affected AP and zone
        - Issue type and location
        """
        try:
            active_incidents = incident_logger.get_active_incidents()
            
            return {
                "success": True,
                "count": len(active_incidents),
                "incidents": active_incidents,
                "timestamp": datetime.now().isoformat()
            }
            
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")
    
    @app.get("/incidents/history", tags=["Incident Management"])
    async def get_incident_history(limit: int = 50):
        """
        📚 **Get Incident History**
        
        Returns recent incident history with optional limit.
        Sorted by timestamp (most recent first).
        """
        try:
            incident_history = incident_logger.get_incident_history(limit=limit)
            
            return {
                "success": True,
                "count": len(incident_history),
                "limit": limit,
                "incidents": incident_history,
                "timestamp": datetime.now().isoformat()
            }
            
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")
    
    @app.get("/zones/{zone}/health", tags=["Zone Management"])
    async def get_zone_health(zone: str):
        """
        🏥 **Get Zone Health Status**
        
        Returns current health statistics for a zone:
        - Total/healthy/down AP counts
        - Health percentage
        - List of affected APs during incidents
        
        **Supported Zones:** FanWiFi, VisitorWiFi, Backstage
        """
        try:
            zone_health = incident_logger._get_zone_health_snapshot(zone)
            
            if "error" in zone_health:
                raise HTTPException(status_code=404, detail=zone_health["error"])
            
            return {
                "success": True,
                "zone_health": zone_health,
                "timestamp": datetime.now().isoformat()
            }
            
        except HTTPException:
            raise
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")
    
    @app.get("/access-points/{ap_id}/incidents", tags=["Access Point Management"])
    async def get_ap_incidents(ap_id: str):
        """
        📡 **Get Access Point Incident History**
        
        Returns all incidents (resolved and active) for a specific access point.
        """
        try:
            ap_incidents = incident_logger.get_ap_incidents(ap_id)
            
            return {
                "success": True,
                "ap_id": ap_id,
                "count": len(ap_incidents),
                "incidents": ap_incidents,
                "timestamp": datetime.now().isoformat()
            }
            
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")
    
    @app.get("/zones/{zone}/incidents", tags=["Zone Management"])
    async def get_zone_incidents(zone: str):
        """
        🌐 **Get Zone Incident History**
        
        Returns all incidents (resolved and active) for a specific zone.
        """
        try:
            zone_incidents = incident_logger.get_zone_incidents(zone)
            
            return {
                "success": True,
                "zone": zone,
                "count": len(zone_incidents),
                "incidents": zone_incidents,
                "timestamp": datetime.now().isoformat()
            }
            
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

# === EXAMPLE CURL COMMANDS FOR TESTING ===

def print_api_examples():
    """Print example API calls for testing."""
    print("""
🚨 LiveOpsLab Incident Management API v2.0

=== Example API Calls ===

1. 📝 Simulate Incident:
curl -X POST "http://localhost:8000/simulate" \\
  -H "Content-Type: application/json" \\
  -d '{
    "ap_id": "AP-01",
    "zone": "FanWiFi", 
    "issue_type": "network_connectivity"
  }'

2. 🔥 Get Active Incidents:
curl -X GET "http://localhost:8000/incidents/active"

3. 🏥 Check Zone Health:
curl -X GET "http://localhost:8000/zones/FanWiFi/health"

4. 🔧 Resolve Incident (replace incident_id):
curl -X POST "http://localhost:8000/resolve-incident" \\
  -H "Content-Type: application/json" \\
  -d '{
    "incident_id": "YOUR_INCIDENT_ID_HERE"
  }'

5. 📚 Get Incident History:
curl -X GET "http://localhost:8000/incidents/history?limit=10"

6. 📡 Get AP Incidents:
curl -X GET "http://localhost:8000/access-points/AP-01/incidents"

7. 🌐 Get Zone Incidents:
curl -X GET "http://localhost:8000/zones/FanWiFi/incidents"

=== Integration Instructions ===

To add to your existing backend/main.py:

1. Copy incident_logger.py to your backend/ directory
2. Add this import: from incident_management import add_incident_routes
3. After creating your FastAPI app, call: add_incident_routes(app)
4. Your network_topology.json file will be updated automatically
5. A new incident_log.json file will be created for logging

=== File Structure ===
📁 Generated Files:
  - incident_log.json (UUID-based incident logging)
  - network_topology.json (updated with zone status changes)
  
📊 Incident Log Entry Example:
{
  "id": "uuid-here",
  "timestamp": "2025-07-29T14:30:00.000000",
  "ap_id": "AP-01", 
  "zone": "FanWiFi",
  "issue_type": "network_connectivity",
  "status": "down",
  "switch_id": "Switch-01",
  "location": {...},
  "resolved": false,
  "resolution_timestamp": null
}
""")

if __name__ == "__main__":
    print_api_examples()
