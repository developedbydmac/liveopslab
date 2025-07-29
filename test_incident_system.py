#!/usr/bin/env python3
"""
Complete end-to-end test of the incident management system.
Tests the POST /simulate route with realistic scenarios.
"""

import json
import requests
from datetime import datetime
from incident_logger import IncidentLogger
from incident_api import simulate_incident_route, resolve_incident_route, get_zone_health_route
from incident_api import IncidentSimulation, IncidentResolution

def test_incident_simulation_complete():
    """Test the complete incident simulation workflow."""
    print("🧪 LiveOpsLab Incident Management - Complete Test")
    print("=" * 60)
    
    # Test different incident types
    test_scenarios = [
        {
            "ap_id": "AP-04", 
            "zone": "FanWiFi", 
            "issue_type": "network_connectivity",
            "description": "Network connectivity failure"
        },
        {
            "ap_id": "AP-12", 
            "zone": "VisitorWiFi", 
            "issue_type": "hardware_malfunction",
            "description": "Access point hardware failure"
        },
        {
            "ap_id": "AP-25", 
            "zone": "Backstage", 
            "issue_type": "power_failure",
            "description": "Power supply interruption"
        }
    ]
    
    incident_ids = []
    
    print("🎬 Scenario Testing:")
    print("-" * 30)
    
    for i, scenario in enumerate(test_scenarios, 1):
        print(f"\n{i}. 🚨 Testing: {scenario['description']}")
        print(f"   📍 Target: {scenario['ap_id']} - {scenario['zone']} zone")
        
        # Create incident simulation request
        incident_request = IncidentSimulation(
            ap_id=scenario["ap_id"],
            zone=scenario["zone"],
            issue_type=scenario["issue_type"]
        )
        
        try:
            # Simulate the incident
            result = simulate_incident_route(incident_request)
            
            print(f"   ✅ Incident Created: {result['incident_id'][:8]}...")
            print(f"   📊 Zone Health: {result['zone_health_snapshot']['health_percentage']:.1f}%")
            print(f"   🔍 Affected APs: {result['zone_health_snapshot']['down_aps']}")
            
            incident_ids.append(result['incident_id'])
            
        except Exception as e:
            print(f"   ❌ Error: {e}")
    
    print(f"\n📈 Summary After Incidents:")
    print("-" * 35)
    
    # Check health of all zones
    zones = ["FanWiFi", "VisitorWiFi", "Backstage"]
    for zone in zones:
        try:
            health_result = get_zone_health_route(zone)
            zone_health = health_result['zone_health']
            status_icon = "🟢" if zone_health['health_percentage'] == 100 else "🔴"
            
            print(f"   {status_icon} {zone}: {zone_health['health_percentage']:.1f}% "
                  f"({zone_health['healthy_aps']}/{zone_health['total_aps']} healthy)")
        except Exception as e:
            print(f"   ❌ {zone}: Error getting health - {e}")
    
    print(f"\n🔧 Resolution Phase:")
    print("-" * 25)
    
    # Resolve all incidents
    for i, incident_id in enumerate(incident_ids, 1):
        print(f"\n{i}. 💚 Resolving Incident: {incident_id[:8]}...")
        
        resolution_request = IncidentResolution(incident_id=incident_id)
        
        try:
            result = resolve_incident_route(resolution_request)
            print(f"   ✅ {result['message']}")
            print(f"   ⏰ Resolution Time: {result['resolution_timestamp']}")
            
        except Exception as e:
            print(f"   ❌ Error: {e}")
    
    print(f"\n📊 Final Health Summary:")
    print("-" * 30)
    
    # Final health check
    total_healthy = 0
    total_aps = 0
    
    for zone in zones:
        try:
            health_result = get_zone_health_route(zone)
            zone_health = health_result['zone_health']
            
            total_healthy += zone_health['healthy_aps']
            total_aps += zone_health['total_aps']
            
            print(f"   🟢 {zone}: {zone_health['health_percentage']:.1f}% healthy")
        except Exception as e:
            print(f"   ❌ {zone}: Error - {e}")
    
    overall_health = (total_healthy / total_aps) * 100 if total_aps > 0 else 0
    print(f"\n🏟️ Overall Network Health: {overall_health:.1f}%")
    print(f"   📡 Total APs: {total_healthy}/{total_aps} operational")
    
    # Show generated files
    print(f"\n📁 Generated Files:")
    print("-" * 20)
    
    try:
        with open("incident_log.json", 'r') as f:
            incidents = json.load(f)
        print(f"   📝 incident_log.json: {len(incidents)} incidents logged")
        
        # Show recent incidents
        print("\n   📋 Recent Incidents:")
        for incident in incidents[-3:]:  # Show last 3
            status = "✅ Resolved" if incident.get('resolved') else "🔥 Active"
            print(f"      - {incident['ap_id']} | {incident['zone']} | {incident['issue_type']} | {status}")
    
    except FileNotFoundError:
        print("   ⚠️  incident_log.json not found")
    
    print(f"\n🎯 Test Complete! Incident management system fully operational.")

def test_api_payload_examples():
    """Show example API payloads for testing."""
    print("\n" + "="*60)
    print("📋 API Testing Payloads")
    print("="*60)
    
    print("\n1. 📝 POST /simulate - Simulate Incident:")
    print("   Request Body:")
    simulate_payload = {
        "ap_id": "AP-01",
        "zone": "FanWiFi",
        "issue_type": "network_connectivity"
    }
    print(f"   {json.dumps(simulate_payload, indent=4)}")
    
    print("\n2. 🔧 POST /resolve-incident - Resolve Incident:")
    print("   Request Body:")
    resolve_payload = {
        "incident_id": "12345678-1234-1234-1234-123456789012"
    }
    print(f"   {json.dumps(resolve_payload, indent=4)}")
    
    print("\n3. 🏥 GET /zones/FanWiFi/health - Zone Health:")
    print("   No request body needed")
    
    print("\n4. 🔥 GET /incidents/active - Active Incidents:")
    print("   No request body needed")

if __name__ == "__main__":
    test_incident_simulation_complete()
    test_api_payload_examples()
