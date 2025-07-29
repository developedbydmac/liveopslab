#!/usr/bin/env python3
"""
Network map generator for LiveOpsLab Dashboard.
Creates network_topology.json with 50 APs in a realistic network layout.
"""

import json
import random
from datetime import datetime

def generate_network_map():
    """Generate a comprehensive network topology map with 50 APs."""
    
    zones = ['FanWiFi', 'VisitorWiFi', 'Backstage']
    access_points = []
    
    # Hardware models and their characteristics
    hardware_models = [
        {"model": "Cisco Catalyst 9130AXI", "max_power": 30, "reliability": 0.95},
        {"model": "Aruba AP-535", "max_power": 25, "reliability": 0.92},
        {"model": "Ubiquiti UniFi 6 Enterprise", "max_power": 22, "reliability": 0.90},
        {"model": "Ruckus R750", "max_power": 28, "reliability": 0.94}
    ]
    
    # Generate 50 access points with realistic distribution
    for i in range(1, 51):
        ap_id = f"AP-{i:02d}"
        
        # Distribute APs across switches (3-4 APs per switch)
        switch_num = ((i - 1) // 3) + 1
        switch_id = f"Switch-{switch_num:02d}"
        
        # Distribute across 4 floors and 4 sections
        floor = ((i - 1) // 12) + 1  # 12-13 APs per floor
        section = ["North", "South", "East", "West"][(i - 1) % 4]
        
        # Select hardware model
        hardware = random.choice(hardware_models)
        
        ap = {
            "ap_id": ap_id,
            "switch_id": switch_id,
            "location": {
                "floor": floor,
                "section": section,
                "building": "Main Arena",
                "coordinates": {
                    "x": 50 + (i % 10) * 30,  # X coordinate in meters
                    "y": 25 + ((i - 1) // 10) * 40  # Y coordinate in meters
                }
            },
            "hardware": {
                "model": hardware["model"],
                "firmware": f"v{random.choice(['2.4.1', '2.4.2', '2.5.0'])}",
                "uptime_hours": random.randint(100, 8760),  # Up to 1 year
                "max_power_watts": hardware["max_power"],
                "reliability_score": hardware["reliability"]
            },
            "network": {
                "ip_address": f"192.168.{100 + floor}.{10 + (i % 50)}",
                "subnet_mask": "255.255.255.0",
                "gateway": f"192.168.{100 + floor}.1",
                "vlan_id": 100 + floor
            },
            "zones": {}
        }
        
        # Generate zone-specific data
        for zone_idx, zone in enumerate(zones):
            # Base performance varies by zone type and location
            if zone == "Backstage":
                base_latency = random.randint(10, 25)  # Critical zone, better performance
                base_throughput = random.uniform(40, 80)
                max_clients = 15  # Limited backstage access
            elif zone == "VisitorWiFi":
                base_latency = random.randint(20, 40)  # Public WiFi, moderate performance
                base_throughput = random.uniform(25, 60)
                max_clients = 50  # Higher visitor capacity
            else:  # FanWiFi
                base_latency = random.randint(15, 35)  # Fan zone, variable performance
                base_throughput = random.uniform(30, 70)
                max_clients = 75  # Highest capacity for fans
            
            # Simulate some current issues (10% chance per zone)
            has_issue = random.random() < 0.1
            
            if has_issue:
                # Determine issue severity
                if random.random() < 0.3:  # 30% of issues are critical
                    status = "down"
                    latency = 0
                    clients = 0
                    throughput = 0.0
                else:
                    status = "warning" 
                    latency = base_latency + random.randint(50, 150)
                    clients = random.randint(0, max_clients // 3)
                    throughput = base_throughput * random.uniform(0.1, 0.4)
            else:
                status = "healthy"
                latency = base_latency + random.randint(-5, 10)
                clients = random.randint(0, max_clients)
                throughput = base_throughput * random.uniform(0.6, 1.0)
            
            ap["zones"][zone] = {
                "status": status,
                "latency_ms": max(0, latency),
                "connected_clients": clients,
                "throughput_mbps": round(max(0, throughput), 1),
                "signal_strength_dbm": random.randint(-45, -25),
                "channel": random.choice([1, 6, 11, 36, 40, 44, 48]),
                "bandwidth_mhz": random.choice([20, 40, 80]),
                "last_updated": datetime.now().isoformat()
            }
        
        access_points.append(ap)
    
    # Create the complete network topology
    network_topology = {
        "metadata": {
            "generated_at": datetime.now().isoformat(),
            "version": "1.0",
            "total_access_points": len(access_points),
            "total_switches": 17,  # 50 APs / 3 per switch = ~17 switches
            "coverage_area": "Sports Arena - 4 floors",
            "zone_types": zones
        },
        "access_points": access_points,
        "switches": {}
    }
    
    # Generate switch information
    for switch_num in range(1, 18):  # 17 switches
        switch_id = f"Switch-{switch_num:02d}"
        floor = ((switch_num - 1) // 5) + 1  # ~4-5 switches per floor
        
        # Count APs connected to this switch
        connected_aps = [ap["ap_id"] for ap in access_points if ap["switch_id"] == switch_id]
        
        network_topology["switches"][switch_id] = {
            "switch_id": switch_id,
            "model": random.choice(["Cisco Catalyst 3850", "HP Aruba 3810M", "Juniper EX4300"]),
            "location": {
                "floor": floor,
                "rack": f"Rack-{switch_num:02d}",
                "room": f"IDF-{floor}-{((switch_num - 1) % 5) + 1}"
            },
            "connected_aps": connected_aps,
            "port_count": 48,
            "poe_budget_watts": 740,
            "poe_consumption_watts": len(connected_aps) * 25,  # ~25W per AP
            "uptime_hours": random.randint(1000, 8760),
            "status": "healthy" if random.random() > 0.05 else "warning",  # 5% chance of issues
            "last_updated": datetime.now().isoformat()
        }
    
    return network_topology

def save_network_map(filename="network_topology.json"):
    """Generate and save the network topology map."""
    print("🗺️  Generating network topology map...")
    
    network_map = generate_network_map()
    
    # Save to JSON file
    with open(filename, 'w') as f:
        json.dump(network_map, f, indent=2)
    
    # Print summary
    print(f"✅ Network map saved to {filename}")
    print(f"📊 Generated {len(network_map['access_points'])} access points")
    print(f"🔌 Generated {len(network_map['switches'])} network switches")
    
    # Print zone health summary
    zones = ['FanWiFi', 'VisitorWiFi', 'Backstage']
    for zone in zones:
        healthy = sum(1 for ap in network_map['access_points'] 
                     if ap['zones'][zone]['status'] == 'healthy')
        warning = sum(1 for ap in network_map['access_points'] 
                     if ap['zones'][zone]['status'] == 'warning')
        down = sum(1 for ap in network_map['access_points'] 
                  if ap['zones'][zone]['status'] == 'down')
        
        total = len(network_map['access_points'])
        health_pct = (healthy / total) * 100
        
        print(f"📡 {zone}: {healthy}✅ {warning}⚠️ {down}❌ ({health_pct:.1f}% healthy)")
    
    return network_map

if __name__ == "__main__":
    save_network_map()
