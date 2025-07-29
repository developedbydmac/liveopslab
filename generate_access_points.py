#!/usr/bin/env python3
"""
Generate 50 access points for LiveOpsLab venue network infrastructure.
Each AP has zones for FanWiFi, VisitorWiFi, and Backstage networks.
"""

import json
import random
from typing import Dict, List, Any

def generate_access_points() -> List[Dict[str, Any]]:
    """
    Generate a list of 50 access points with realistic network data.
    
    Returns:
        List of access point dictionaries with zones and metrics
    """
    access_points = []
    
    # Switch pool (20 switches)
    switches = [f"Switch-{i:02d}" for i in range(1, 21)]
    
    # Zone types
    zones = ["FanWiFi", "VisitorWiFi", "Backstage"]
    
    for ap_num in range(1, 51):
        ap_id = f"AP-{ap_num:02d}"
        switch_id = random.choice(switches)
        
        # Generate zone data for each AP
        zone_data = {}
        for zone in zones:
            zone_data[zone] = {
                "status": "healthy",
                "latency_ms": random.randint(20, 60),
                "signal_strength": random.randint(-45, -25),  # dBm
                "connected_clients": random.randint(0, 50),
                "throughput_mbps": round(random.uniform(10.5, 95.8), 1),
                "last_updated": "2025-07-29T12:00:00Z"
            }
        
        access_point = {
            "ap_id": ap_id,
            "switch_id": switch_id,
            "location": {
                "building": "Main Venue",
                "floor": random.choice([1, 2, 3]),
                "section": random.choice(["North", "South", "East", "West", "Center"])
            },
            "hardware": {
                "model": random.choice(["Cisco WAP581", "Ubiquiti UAP-AC-HD", "Aruba AP-515"]),
                "firmware": "v2.4.1",
                "uptime_hours": random.randint(24, 8760)  # 1 day to 1 year
            },
            "zones": zone_data,
            "management": {
                "ip_address": f"192.168.{random.randint(10, 50)}.{random.randint(2, 254)}",
                "mac_address": f"00:1B:44:{random.randint(10, 99):02d}:{random.randint(10, 99):02d}:{random.randint(10, 99):02d}",
                "ssh_enabled": True,
                "snmp_community": "public"
            }
        }
        
        access_points.append(access_point)
    
    return access_points

def generate_switch_mapping() -> Dict[str, Dict[str, Any]]:
    """
    Generate switch information for the 20 switches.
    
    Returns:
        Dictionary mapping switch IDs to switch details
    """
    switches = {}
    
    for switch_num in range(1, 21):
        switch_id = f"Switch-{switch_num:02d}"
        switches[switch_id] = {
            "switch_id": switch_id,
            "model": random.choice(["Cisco Catalyst 2960", "HP ProCurve 2920", "Juniper EX2300"]),
            "port_count": random.choice([24, 48]),
            "uplink_ports": 4,
            "management_ip": f"192.168.1.{switch_num + 100}",
            "location": {
                "rack": f"Rack-{random.randint(1, 10):02d}",
                "position": f"U{random.randint(1, 42)}"
            },
            "connected_aps": [],  # Will be populated based on AP assignments
            "status": "operational",
            "cpu_usage": random.randint(5, 25),
            "memory_usage": random.randint(30, 70)
        }
    
    return switches

def update_switch_ap_mapping(access_points: List[Dict], switches: Dict[str, Dict]) -> Dict[str, Dict]:
    """
    Update switch data with connected AP information.
    
    Args:
        access_points: List of access point data
        switches: Dictionary of switch data
        
    Returns:
        Updated switches dictionary with AP mappings
    """
    # Reset connected_aps lists
    for switch_data in switches.values():
        switch_data["connected_aps"] = []
    
    # Populate connected APs for each switch
    for ap in access_points:
        switch_id = ap["switch_id"]
        if switch_id in switches:
            switches[switch_id]["connected_aps"].append({
                "ap_id": ap["ap_id"],
                "port": f"GigabitEthernet0/{len(switches[switch_id]['connected_aps']) + 1}",
                "status": "up"
            })
    
    return switches

def save_to_files(access_points: List[Dict], switches: Dict[str, Dict]):
    """
    Save generated data to JSON files.
    
    Args:
        access_points: List of access point data
        switches: Dictionary of switch data
    """
    # Save access points
    with open("access_points.json", "w") as f:
        json.dump(access_points, f, indent=2)
    
    # Save switches
    with open("switches.json", "w") as f:
        json.dump(switches, f, indent=2)
    
    # Save combined network topology
    network_topology = {
        "venue_name": "LiveOpsLab Venue",
        "generated_at": "2025-07-29T12:00:00Z",
        "total_access_points": len(access_points),
        "total_switches": len(switches),
        "zones": ["FanWiFi", "VisitorWiFi", "Backstage"],
        "access_points": access_points,
        "switches": switches
    }
    
    with open("network_topology.json", "w") as f:
        json.dump(network_topology, f, indent=2)

def print_summary(access_points: List[Dict], switches: Dict[str, Dict]):
    """
    Print a summary of generated network infrastructure.
    
    Args:
        access_points: List of access point data
        switches: Dictionary of switch data
    """
    print("🏟️ LiveOpsLab Network Infrastructure Generated")
    print("=" * 50)
    print(f"📡 Access Points: {len(access_points)}")
    print(f"🔌 Switches: {len(switches)}")
    print(f"🌐 Zones per AP: 3 (FanWiFi, VisitorWiFi, Backstage)")
    print()
    
    # AP distribution by switch
    ap_distribution = {}
    for ap in access_points:
        switch_id = ap["switch_id"]
        ap_distribution[switch_id] = ap_distribution.get(switch_id, 0) + 1
    
    print("📊 AP Distribution by Switch:")
    for switch_id, count in sorted(ap_distribution.items()):
        print(f"  {switch_id}: {count} APs")
    
    print()
    print("📁 Files Generated:")
    print("  - access_points.json (AP details)")
    print("  - switches.json (Switch details)")
    print("  - network_topology.json (Complete topology)")
    print()
    
    # Zone health summary
    zone_stats = {"FanWiFi": [], "VisitorWiFi": [], "Backstage": []}
    for ap in access_points:
        for zone, data in ap["zones"].items():
            zone_stats[zone].append(data["latency_ms"])
    
    print("🔍 Zone Performance Summary:")
    for zone, latencies in zone_stats.items():
        avg_latency = sum(latencies) / len(latencies)
        print(f"  {zone}: Avg latency {avg_latency:.1f}ms (Range: {min(latencies)}-{max(latencies)}ms)")

if __name__ == "__main__":
    print("Generating LiveOpsLab network infrastructure...")
    
    # Generate access points
    access_points = generate_access_points()
    
    # Generate switches
    switches = generate_switch_mapping()
    
    # Update switch-AP mappings
    switches = update_switch_ap_mapping(access_points, switches)
    
    # Save to files
    save_to_files(access_points, switches)
    
    # Print summary
    print_summary(access_points, switches)
    
    print("\n✅ Network infrastructure generation complete!")
