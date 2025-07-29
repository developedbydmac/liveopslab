#!/usr/bin/env python3
"""
FastAPI routes for incident simulation and management.
Integrates with IncidentLogger for network state management.
"""

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from typing import Dict, List, Any, Optional
from datetime import datetime
import uuid

from incident_logger import IncidentLogger

# Initialize incident logger
incident_logger = IncidentLogger()

# Pydantic models for API requests
class IncidentSimulation(BaseModel):
    ap_id: str = Field(..., description="Access Point ID (e.g., 'AP-01')")
    zone: str = Field(..., description="Zone name (FanWiFi, VisitorWiFi, Backstage)")
    issue_type: str = Field(..., description="Type of issue (network_connectivity, power_failure, hardware_malfunction, etc.)")

class IncidentResolution(BaseModel):
    incident_id: str = Field(..., description="UUID of the incident to resolve")

# FastAPI route implementations
def simulate_incident_route(incident: IncidentSimulation) -> Dict[str, Any]:
    """
    POST /simulate
    Simulate an incident by updating zone status and logging the event.
    
    Args:
        incident: IncidentSimulation model with ap_id, zone, and issue_type
        
    Returns:
        Incident details with zone health snapshot
    """
    try:
        result = incident_logger.simulate_incident(
            ap_id=incident.ap_id,
            zone=incident.zone,
            issue_type=incident.issue_type
        )
        
        return {
            "success": True,
            "incident_id": result["incident_id"],
            "status": result["status"],
            "message": result["message"],
            "incident_details": result["incident_details"],
            "zone_health_snapshot": result["zone_health_snapshot"],
            "timestamp": datetime.now().isoformat()
        }
        
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

def resolve_incident_route(resolution: IncidentResolution) -> Dict[str, Any]:
    """
    POST /resolve-incident
    Resolve an active incident and restore zone health.
    
    Args:
        resolution: IncidentResolution model with incident_id
        
    Returns:
        Resolution confirmation details
    """
    try:
        result = incident_logger.resolve_incident(resolution.incident_id)
        
        return {
            "success": True,
            "status": result["status"],
            "message": result["message"],
            "incident_id": result.get("incident_id"),
            "resolution_timestamp": result.get("resolution_timestamp"),
            "timestamp": datetime.now().isoformat()
        }
        
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

def get_active_incidents_route() -> Dict[str, Any]:
    """
    GET /incidents/active
    Get all currently active (unresolved) incidents.
    
    Returns:
        List of active incidents
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

def get_incident_history_route(limit: int = 50) -> Dict[str, Any]:
    """
    GET /incidents/history
    Get recent incident history.
    
    Args:
        limit: Maximum number of incidents to return (default: 50)
        
    Returns:
        List of recent incidents
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

def get_zone_health_route(zone: str) -> Dict[str, Any]:
    """
    GET /zones/{zone}/health
    Get current health status for a specific zone.
    
    Args:
        zone: Zone name (FanWiFi, VisitorWiFi, Backstage)
        
    Returns:
        Zone health snapshot
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

def get_ap_incidents_route(ap_id: str) -> Dict[str, Any]:
    """
    GET /access-points/{ap_id}/incidents
    Get all incidents for a specific access point.
    
    Args:
        ap_id: Access Point ID (e.g., "AP-01")
        
    Returns:
        List of incidents for the specified AP
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

def get_zone_incidents_route(zone: str) -> Dict[str, Any]:
    """
    GET /zones/{zone}/incidents
    Get all incidents for a specific zone.
    
    Args:
        zone: Zone name (FanWiFi, VisitorWiFi, Backstage)
        
    Returns:
        List of incidents for the specified zone
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

# Demo function to test the routes
def demo_api_routes():
    """Demonstrate the incident management API routes."""
    print("🚨 LiveOpsLab Incident Management API Demo")
    print("=" * 55)
    
    # Test incident simulation
    print("1. 📝 Simulating Incident...")
    incident_data = IncidentSimulation(
        ap_id="AP-01",
        zone="FanWiFi",
        issue_type="network_connectivity"
    )
    
    try:
        result = simulate_incident_route(incident_data)
        print(f"   ✅ Success: {result['message']}")
        print(f"   🆔 Incident ID: {result['incident_id']}")
        print(f"   📊 Zone Health: {result['zone_health_snapshot']['healthy_aps']}/{result['zone_health_snapshot']['total_aps']} healthy")
        incident_id = result['incident_id']
        print()
        
        # Test active incidents
        print("2. 🔥 Getting Active Incidents...")
        active_result = get_active_incidents_route()
        print(f"   📋 Active Incidents: {active_result['count']}")
        for inc in active_result['incidents'][-2:]:  # Show last 2
            print(f"      - {inc['ap_id']} | {inc['zone']} | {inc['issue_type']}")
        print()
        
        # Test zone health
        print("3. 🏥 Checking Zone Health...")
        health_result = get_zone_health_route("FanWiFi")
        zone_health = health_result['zone_health']
        print(f"   🌐 FanWiFi Zone:")
        print(f"      - Health: {zone_health['health_percentage']:.1f}%")
        print(f"      - Status: {zone_health['healthy_aps']}/{zone_health['total_aps']} APs healthy")
        print(f"      - Down APs: {zone_health['down_aps']}")
        print()
        
        # Test incident history
        print("4. 📚 Getting Incident History...")
        history_result = get_incident_history_route(limit=5)
        print(f"   📜 Recent Incidents: {history_result['count']}")
        for inc in history_result['incidents'][:2]:  # Show first 2
            status = "✅ Resolved" if inc.get('resolved') else "🔥 Active"
            print(f"      - {inc['ap_id']} | {inc['zone']} | {status}")
        print()
        
        # Test incident resolution
        print("5. 🔧 Resolving Incident...")
        resolution_data = IncidentResolution(incident_id=incident_id)
        resolve_result = resolve_incident_route(resolution_data)
        print(f"   ✅ {resolve_result['message']}")
        print(f"   ⏰ Resolved at: {resolve_result['resolution_timestamp']}")
        print()
        
        # Test updated zone health
        print("6. 🏥 Checking Updated Zone Health...")
        updated_health = get_zone_health_route("FanWiFi")
        zone_health = updated_health['zone_health']
        print(f"   🌐 FanWiFi Zone (After Resolution):")
        print(f"      - Health: {zone_health['health_percentage']:.1f}%")
        print(f"      - Status: {zone_health['healthy_aps']}/{zone_health['total_aps']} APs healthy")
        
    except Exception as e:
        print(f"   ❌ Error: {e}")

# Example FastAPI app integration
def create_incident_management_app() -> FastAPI:
    """
    Create a FastAPI app with incident management routes.
    This can be integrated into your existing LiveOpsLab FastAPI app.
    """
    app = FastAPI(title="LiveOpsLab Incident Management", version="2.0.0")
    
    # Main incident simulation route
    @app.post("/simulate")
    async def simulate_incident(incident: IncidentSimulation):
        """Simulate an incident and update zone status."""
        return simulate_incident_route(incident)
    
    # Incident resolution route
    @app.post("/resolve-incident")
    async def resolve_incident(resolution: IncidentResolution):
        """Resolve an active incident."""
        return resolve_incident_route(resolution)
    
    # Get active incidents
    @app.get("/incidents/active")
    async def get_active_incidents():
        """Get all active incidents."""
        return get_active_incidents_route()
    
    # Get incident history
    @app.get("/incidents/history")
    async def get_incident_history(limit: int = 50):
        """Get recent incident history."""
        return get_incident_history_route(limit)
    
    # Get zone health
    @app.get("/zones/{zone}/health")
    async def get_zone_health(zone: str):
        """Get health status for a specific zone."""
        return get_zone_health_route(zone)
    
    # Get AP incidents
    @app.get("/access-points/{ap_id}/incidents")
    async def get_ap_incidents(ap_id: str):
        """Get all incidents for a specific access point."""
        return get_ap_incidents_route(ap_id)
    
    # Get zone incidents
    @app.get("/zones/{zone}/incidents")
    async def get_zone_incidents(zone: str):
        """Get all incidents for a specific zone."""
        return get_zone_incidents_route(zone)
    
    return app

if __name__ == "__main__":
    demo_api_routes()
