#!/usr/bin/env python3
"""
Example FastAPI endpoints using the generated access points data.
This shows how to integrate the network topology with your existing backend.
"""

from fastapi import FastAPI, HTTPException
from typing import Dict, List, Any, Optional
from pydantic import BaseModel
import json
from network_topology_manager import NetworkTopologyManager

# Initialize the topology manager
topology_manager = NetworkTopologyManager()

# Pydantic models for API requests/responses
class OutageSimulation(BaseModel):
    ap_id: str
    zone: str
    duration_minutes: int = 5

class ZoneRecovery(BaseModel):
    ap_id: str
    zone: str

class APQuery(BaseModel):
    floor: Optional[int] = None
    section: Optional[str] = None
    switch_id: Optional[str] = None

# Example API endpoints (to be added to your existing FastAPI app)

def get_network_topology() -> Dict[str, Any]:
    """
    GET /network-topology
    Get complete network topology overview.
    """
    return {
        "total_access_points": len(topology_manager.get_all_access_points()),
        "total_switches": len(topology_manager.get_all_switches()),
        "zone_health": topology_manager.get_zone_health_summary(),
        "switch_loads": topology_manager.get_switch_load_distribution()
    }

def get_access_points(
    zone: Optional[str] = None,
    floor: Optional[int] = None,
    section: Optional[str] = None,
    switch_id: Optional[str] = None
) -> List[Dict[str, Any]]:
    """
    GET /access-points
    Get access points with optional filtering.
    """
    if zone:
        return topology_manager.get_access_points_by_zone(zone)
    
    # Build criteria dict for filtering
    criteria = {}
    if floor is not None:
        criteria["floor"] = floor
    if section:
        criteria["section"] = section
    if switch_id:
        criteria["switch_id"] = switch_id
    
    if criteria:
        return topology_manager.find_aps_by_criteria(**criteria)
    
    return topology_manager.get_all_access_points()

def get_access_point_detail(ap_id: str) -> Dict[str, Any]:
    """
    GET /access-points/{ap_id}
    Get detailed information for a specific access point.
    """
    ap = topology_manager.get_access_point(ap_id)
    if not ap:
        raise HTTPException(status_code=404, detail=f"Access point {ap_id} not found")
    return ap

def simulate_ap_outage(outage: OutageSimulation) -> Dict[str, str]:
    """
    POST /simulate-ap-outage
    Simulate an outage for a specific AP zone.
    """
    success = topology_manager.simulate_outage(
        outage.ap_id, 
        outage.zone, 
        outage.duration_minutes
    )
    
    if not success:
        raise HTTPException(
            status_code=404, 
            detail=f"Access point {outage.ap_id} or zone {outage.zone} not found"
        )
    
    return {
        "status": "success",
        "message": f"Simulated outage for {outage.ap_id} zone {outage.zone} for {outage.duration_minutes} minutes"
    }

def recover_ap_zone(recovery: ZoneRecovery) -> Dict[str, str]:
    """
    POST /recover-ap-zone
    Recover an AP zone from outage.
    """
    success = topology_manager.recover_zone(recovery.ap_id, recovery.zone)
    
    if not success:
        raise HTTPException(
            status_code=404, 
            detail=f"Access point {recovery.ap_id} or zone {recovery.zone} not found"
        )
    
    return {
        "status": "success",
        "message": f"Recovered {recovery.ap_id} zone {recovery.zone}"
    }

def get_zone_health(zone: str) -> Dict[str, Any]:
    """
    GET /zones/{zone}/health
    Get health statistics for a specific zone.
    """
    zone_aps = topology_manager.get_access_points_by_zone(zone)
    if not zone_aps:
        raise HTTPException(status_code=404, detail=f"Zone {zone} not found")
    
    health_summary = topology_manager.get_zone_health_summary()
    return health_summary.get(zone, {})

def get_switch_details(switch_id: str) -> Dict[str, Any]:
    """
    GET /switches/{switch_id}
    Get detailed information for a specific switch.
    """
    switch = topology_manager.get_switch_info(switch_id)
    if not switch:
        raise HTTPException(status_code=404, detail=f"Switch {switch_id} not found")
    
    return switch

def get_switches_overview() -> Dict[str, Any]:
    """
    GET /switches
    Get overview of all switches with load information.
    """
    return {
        "switches": topology_manager.get_all_switches(),
        "load_distribution": topology_manager.get_switch_load_distribution()
    }

# Example usage functions
def demo_api_calls():
    """Demonstrate the API functionality."""
    print("🔌 Network Topology API Demo")
    print("=" * 40)
    
    # Network overview
    print("📊 Network Overview:")
    overview = get_network_topology()
    print(f"  Access Points: {overview['total_access_points']}")
    print(f"  Switches: {overview['total_switches']}")
    print()
    
    # Zone health
    print("🏥 Zone Health:")
    for zone, health in overview['zone_health'].items():
        print(f"  {zone}: {health['healthy_aps']}/{health['total_aps']} healthy")
    print()
    
    # AP filtering examples
    print("🔍 Filtered Access Points:")
    fanwifi_aps = get_access_points(zone="FanWiFi")
    print(f"  FanWiFi zone: {len(fanwifi_aps)} APs")
    
    floor2_aps = get_access_points(floor=2)
    print(f"  Floor 2: {len(floor2_aps)} APs")
    print()
    
    # AP detail
    print("📡 Access Point Detail (AP-01):")
    ap_detail = get_access_point_detail("AP-01")
    print(f"  Location: Floor {ap_detail['location']['floor']}, {ap_detail['location']['section']}")
    print(f"  Switch: {ap_detail['switch_id']}")
    print(f"  Model: {ap_detail['hardware']['model']}")
    print()
    
    # Simulate outage
    print("⚠️  Simulating Outage:")
    outage = OutageSimulation(ap_id="AP-01", zone="FanWiFi", duration_minutes=2)
    result = simulate_ap_outage(outage)
    print(f"  {result['message']}")
    
    # Check updated health
    updated_health = get_zone_health("FanWiFi")
    print(f"  Updated FanWiFi health: {updated_health['healthy_aps']}/{updated_health['total_aps']} healthy")
    
    # Recover zone
    recovery = ZoneRecovery(ap_id="AP-01", zone="FanWiFi")
    result = recover_ap_zone(recovery)
    print(f"  {result['message']}")
    print()
    
    # Switch details
    print("🔌 Switch Details (Switch-01):")
    switch_detail = get_switch_details("Switch-01")
    print(f"  Model: {switch_detail['model']}")
    print(f"  Connected APs: {len(switch_detail['connected_aps'])}")
    print(f"  CPU Usage: {switch_detail['cpu_usage']}%")

if __name__ == "__main__":
    demo_api_calls()
