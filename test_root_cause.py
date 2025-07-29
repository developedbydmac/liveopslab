#!/usr/bin/env python3
"""
Test and demonstrate the root cause analysis function.
Shows complete JSON responses for different incident types.
"""

import json
from incident_logger import IncidentLogger

def test_root_cause_analysis():
    """Test root cause analysis with different scenarios."""
    print("🔍 LiveOpsLab Root Cause Analysis - Complete Demo")
    print("=" * 65)
    
    # Initialize incident logger
    logger = IncidentLogger()
    
    # Test scenarios covering different issue types
    test_scenarios = [
        {
            "ap_id": "AP-01", 
            "zone": "FanWiFi", 
            "issue_type": "network_connectivity",
            "description": "🌐 Network Connectivity Issue"
        },
        {
            "ap_id": "AP-04", 
            "zone": "Backstage", 
            "issue_type": "power_failure",
            "description": "⚡ Power Supply Failure"
        },
        {
            "ap_id": "AP-12", 
            "zone": "VisitorWiFi", 
            "issue_type": "hardware_malfunction",
            "description": "🔧 Hardware Malfunction"
        },
        {
            "ap_id": "AP-25", 
            "zone": "FanWiFi", 
            "issue_type": "high_latency",
            "description": "🐌 High Latency Issue"
        },
        {
            "ap_id": "AP-33", 
            "zone": "Backstage", 
            "issue_type": "authentication_failure",
            "description": "🔐 Authentication Failure"
        }
    ]
    
    for i, scenario in enumerate(test_scenarios, 1):
        print(f"\n{i}. {scenario['description']}")
        print("-" * 50)
        print(f"📍 Target: {scenario['ap_id']} | {scenario['zone']} zone | {scenario['issue_type']}")
        print()
        
        # Generate root cause analysis
        analysis = logger.generate_root_cause(
            scenario["ap_id"],
            scenario["zone"], 
            scenario["issue_type"]
        )
        
        if "error" not in analysis:
            # Display key information
            print("🎯 **Root Cause Analysis:**")
            print(f"   Root Cause: {analysis['root_cause']}")
            print(f"   Fix Suggestion: {analysis['fix_suggestion']}")
            print(f"   Recovery Time: {analysis['estimated_recovery_seconds']} seconds")
            print(f"   Confidence Level: {analysis['confidence_level']}%")
            print()
            
            print("🏗️  **Infrastructure Context:**")
            print(f"   Switch: {analysis['switch_id']}")
            print(f"   Hardware: {analysis['hardware_model']}")
            print(f"   Location: Floor {analysis['location'].get('floor', 'Unknown')}, {analysis['location'].get('section', 'Unknown')} section")
            print()
            
            print("📋 **Troubleshooting Steps:**")
            for step in analysis['troubleshooting_steps'][:5]:  # Show first 5 steps
                print(f"   {step}")
            print(f"   ... and {len(analysis['troubleshooting_steps']) - 5} more steps")
            print()
            
            print("🔍 **Additional Context:**")
            env_factors = analysis['additional_context'].get('environmental_factors', [])
            if env_factors:
                print(f"   Environmental: {', '.join(env_factors)}")
            
            hist_patterns = analysis['additional_context'].get('historical_patterns', [])
            if hist_patterns:
                print(f"   Historical: {', '.join(hist_patterns)}")
            
            network_status = analysis['additional_context'].get('network_topology', {})
            print(f"   Network Status: Switch Load: {network_status.get('switch_load', 'Unknown')}")
            print()
            
        else:
            print(f"❌ Error: {analysis['error']}")
        
        # Show complete JSON for first scenario
        if i == 1:
            print("📄 **Complete JSON Response:**")
            print("```json")
            print(json.dumps(analysis, indent=2))
            print("```")
        
        print("\n" + "=" * 65)

def test_root_cause_api_integration():
    """Show how to integrate root cause analysis with incident simulation."""
    print("\n🔗 API Integration Example")
    print("=" * 40)
    
    logger = IncidentLogger()
    
    # Simulate incident with root cause analysis
    ap_id = "AP-15"
    zone = "FanWiFi"
    issue_type = "network_connectivity"
    
    print(f"1. 🚨 Simulating incident: {ap_id} - {zone} - {issue_type}")
    
    # Generate root cause before incident simulation
    root_cause = logger.generate_root_cause(ap_id, zone, issue_type)
    
    print(f"2. 🔍 Root cause identified: {root_cause['root_cause']}")
    print(f"3. 🔧 Suggested fix: {root_cause['fix_suggestion']}")
    print(f"4. ⏱️  Estimated recovery: {root_cause['estimated_recovery_seconds']}s")
    
    # Simulate the actual incident
    incident = logger.simulate_incident(ap_id, zone, issue_type)
    
    print(f"5. 📝 Incident logged: {incident['incident_id'][:8]}...")
    
    # Combined response format
    combined_response = {
        "incident_simulation": {
            "incident_id": incident["incident_id"],
            "status": incident["status"],
            "message": incident["message"],
            "zone_health": incident["zone_health_snapshot"]
        },
        "root_cause_analysis": {
            "root_cause": root_cause["root_cause"],
            "fix_suggestion": root_cause["fix_suggestion"],
            "estimated_recovery_seconds": root_cause["estimated_recovery_seconds"],
            "confidence_level": root_cause["confidence_level"],
            "troubleshooting_steps": root_cause["troubleshooting_steps"][:3]  # First 3 steps
        }
    }
    
    print("\n📋 **Combined API Response Format:**")
    print("```json")
    print(json.dumps(combined_response, indent=2))
    print("```")
    
    # Clean up - resolve the incident
    logger.resolve_incident(incident["incident_id"])
    print(f"\n✅ Incident resolved for demo cleanup")

if __name__ == "__main__":
    test_root_cause_analysis()
    test_root_cause_api_integration()
