#!/usr/bin/env python3
"""
Live Demo Simulator for LiveOpsLab Network Dashboard
Simulates real-time network incidents, auto-healing, and root cause analysis
"""

import json
import time
import random
import threading
from datetime import datetime, timedelta
from typing import Dict, List, Any

class LiveDemoSimulator:
    def __init__(self):
        self.network_data = None
        self.running = False
        self.incidents = []
        self.auto_heal_probability = 0.3  # 30% chance of auto-healing
        self.incident_probability = 0.05  # 5% chance of new incident per cycle
        
        # Root cause categories and their healing times
        self.root_causes = {
            "Power fluctuation": {"heal_time": 30, "severity": "warning", "auto_heal": 0.8},
            "Network congestion": {"heal_time": 45, "severity": "warning", "auto_heal": 0.6},
            "Hardware failure": {"heal_time": 120, "severity": "down", "auto_heal": 0.1},
            "Configuration error": {"heal_time": 60, "severity": "warning", "auto_heal": 0.4},
            "ISP connectivity": {"heal_time": 90, "severity": "down", "auto_heal": 0.2},
            "Firmware bug": {"heal_time": 180, "severity": "down", "auto_heal": 0.1},
            "Temperature spike": {"heal_time": 25, "severity": "warning", "auto_heal": 0.9},
            "Cable disconnection": {"heal_time": 300, "severity": "down", "auto_heal": 0.05},
            "Authentication server": {"heal_time": 75, "severity": "warning", "auto_heal": 0.3},
            "DHCP pool exhaustion": {"heal_time": 40, "severity": "warning", "auto_heal": 0.7}
        }
        
        self.initialize_network_data()

    def initialize_network_data(self):
        """Initialize the network topology with healthy status."""
        access_points = []
        
        for i in range(1, 51):
            ap_id = f"AP-{i:02d}"
            switch_id = f"Switch-{((i-1)//3 + 1):02d}"
            
            ap = {
                "ap_id": ap_id,
                "switch_id": switch_id,
                "location": {
                    "floor": (i - 1) // 12 + 1,
                    "section": ["North", "South", "East", "West"][(i - 1) % 4]
                },
                "hardware": {
                    "model": ["Cisco Catalyst 9130AXI", "Aruba AP-535", "Ubiquiti UniFi 6 Enterprise"][i % 3],
                    "uptime_hours": random.randint(100, 8760),
                    "temperature_c": random.randint(35, 55),
                    "cpu_usage": random.randint(10, 30)
                },
                "zones": {},
                "incidents": [],
                "last_incident": None
            }
            
            # Initialize all zones as healthy
            zones = ['FanWiFi', 'VisitorWiFi', 'Backstage']
            for zone in zones:
                ap["zones"][zone] = {
                    "status": "healthy",
                    "latency_ms": random.randint(8, 25),
                    "connected_clients": random.randint(5, 30),
                    "throughput_mbps": round(random.uniform(50, 95), 1),
                    "last_updated": datetime.now().isoformat(),
                    "root_cause": None,
                    "incident_id": None,
                    "healing_eta": None
                }
            
            access_points.append(ap)
        
        self.network_data = {
            "access_points": access_points,
            "last_updated": datetime.now().isoformat(),
            "simulation_active": True,
            "active_incidents": 0,
            "total_incidents": 0,
            "auto_healed": 0
        }

    def generate_incident(self) -> Dict[str, Any]:
        """Generate a random network incident."""
        incident_id = f"INC-{len(self.incidents) + 1:04d}"
        root_cause = random.choice(list(self.root_causes.keys()))
        cause_info = self.root_causes[root_cause]
        
        # Select random AP and zone
        ap = random.choice(self.network_data["access_points"])
        zone = random.choice(list(ap["zones"].keys()))
        
        incident = {
            "incident_id": incident_id,
            "ap_id": ap["ap_id"],
            "zone": zone,
            "root_cause": root_cause,
            "severity": cause_info["severity"],
            "start_time": datetime.now(),
            "estimated_heal_time": datetime.now() + timedelta(seconds=cause_info["heal_time"]),
            "auto_heal_probability": cause_info["auto_heal"],
            "status": "active",
            "description": self.get_incident_description(root_cause, ap["ap_id"], zone)
        }
        
        return incident

    def get_incident_description(self, root_cause: str, ap_id: str, zone: str) -> str:
        """Generate a descriptive incident message."""
        descriptions = {
            "Power fluctuation": f"Power supply instability detected on {ap_id} affecting {zone} network",
            "Network congestion": f"High traffic volume causing packet loss in {zone} on {ap_id}",
            "Hardware failure": f"Radio module malfunction detected on {ap_id} for {zone} service",
            "Configuration error": f"Invalid VLAN configuration blocking {zone} traffic on {ap_id}",
            "ISP connectivity": f"Upstream connectivity loss affecting {ap_id} {zone} gateway",
            "Firmware bug": f"Known firmware issue causing {zone} service interruption on {ap_id}",
            "Temperature spike": f"Overheating detected on {ap_id}, throttling {zone} performance",
            "Cable disconnection": f"Physical cable issue detected between {ap_id} and core switch",
            "Authentication server": f"RADIUS authentication timeout affecting {zone} users on {ap_id}",
            "DHCP pool exhaustion": f"No available IP addresses for new {zone} clients on {ap_id}"
        }
        
        return descriptions.get(root_cause, f"Unknown issue affecting {ap_id} {zone}")

    def apply_incident(self, incident: Dict[str, Any]):
        """Apply an incident to the network data."""
        for ap in self.network_data["access_points"]:
            if ap["ap_id"] == incident["ap_id"]:
                zone_data = ap["zones"][incident["zone"]]
                
                # Update zone status
                zone_data["status"] = incident["severity"]
                zone_data["root_cause"] = incident["root_cause"]
                zone_data["incident_id"] = incident["incident_id"]
                zone_data["healing_eta"] = incident["estimated_heal_time"].isoformat()
                zone_data["last_updated"] = datetime.now().isoformat()
                
                # Degrade performance based on severity
                if incident["severity"] == "down":
                    zone_data["latency_ms"] = random.randint(200, 500)
                    zone_data["connected_clients"] = random.randint(0, 3)
                    zone_data["throughput_mbps"] = round(random.uniform(0, 5), 1)
                else:  # warning
                    zone_data["latency_ms"] = random.randint(80, 150)
                    zone_data["connected_clients"] = random.randint(2, 8)
                    zone_data["throughput_mbps"] = round(random.uniform(15, 35), 1)
                
                # Add to AP incidents list
                ap["incidents"].append(incident)
                ap["last_incident"] = incident["incident_id"]
                
                break
        
        self.incidents.append(incident)
        self.network_data["active_incidents"] += 1
        self.network_data["total_incidents"] += 1

    def check_auto_healing(self):
        """Check for incidents that should auto-heal."""
        current_time = datetime.now()
        healed_incidents = []
        
        for incident in self.incidents:
            if incident["status"] == "active":
                # Check if it's time to heal
                time_elapsed = (current_time - incident["start_time"]).total_seconds()
                heal_time = (incident["estimated_heal_time"] - incident["start_time"]).total_seconds()
                
                # Auto-heal based on probability and time
                should_heal = (
                    time_elapsed >= heal_time * 0.5 and  # At least 50% of heal time passed
                    random.random() < incident["auto_heal_probability"]
                ) or time_elapsed >= heal_time  # Force heal after full time
                
                if should_heal:
                    self.heal_incident(incident)
                    healed_incidents.append(incident)
        
        return healed_incidents

    def heal_incident(self, incident: Dict[str, Any]):
        """Heal an incident and restore normal operation."""
        incident["status"] = "resolved"
        incident["end_time"] = datetime.now()
        incident["resolution"] = "Auto-healed by system monitoring"
        
        # Find and update the affected AP/zone
        for ap in self.network_data["access_points"]:
            if ap["ap_id"] == incident["ap_id"]:
                zone_data = ap["zones"][incident["zone"]]
                
                # Restore healthy status
                zone_data["status"] = "healthy"
                zone_data["latency_ms"] = random.randint(8, 25)
                zone_data["connected_clients"] = random.randint(15, 30)
                zone_data["throughput_mbps"] = round(random.uniform(60, 95), 1)
                zone_data["root_cause"] = None
                zone_data["incident_id"] = None
                zone_data["healing_eta"] = None
                zone_data["last_updated"] = datetime.now().isoformat()
                
                break
        
        self.network_data["active_incidents"] -= 1
        self.network_data["auto_healed"] += 1

    def save_network_data(self):
        """Save current network state to JSON file."""
        self.network_data["last_updated"] = datetime.now().isoformat()
        
        with open('network_topology.json', 'w') as f:
            json.dump(self.network_data, f, indent=2, default=str)

    def run_simulation(self):
        """Main simulation loop."""
        print("🚀 Starting Live Demo Simulation...")
        print("✅ Network initialized with 50 APs, all healthy")
        
        cycle = 0
        while self.running:
            cycle += 1
            print(f"\n🔄 Simulation Cycle {cycle}")
            
            # Check for auto-healing
            healed = self.check_auto_healing()
            if healed:
                for incident in healed:
                    print(f"🩹 AUTO-HEALED: {incident['ap_id']} {incident['zone']} - {incident['root_cause']}")
            
            # Generate new incidents
            if random.random() < self.incident_probability:
                incident = self.generate_incident()
                self.apply_incident(incident)
                print(f"🚨 NEW INCIDENT: {incident['ap_id']} {incident['zone']} - {incident['root_cause']}")
                print(f"   Severity: {incident['severity']} | ETA: {incident['estimated_heal_time'].strftime('%H:%M:%S')}")
            
            # Update network metrics
            for ap in self.network_data["access_points"]:
                for zone_name, zone_data in ap["zones"].items():
                    if zone_data["status"] == "healthy":
                        # Add small random variations to healthy zones
                        zone_data["latency_ms"] += random.randint(-2, 2)
                        zone_data["latency_ms"] = max(5, min(30, zone_data["latency_ms"]))
                        zone_data["last_updated"] = datetime.now().isoformat()
            
            # Save updated data
            self.save_network_data()
            
            # Status report
            active_incidents = self.network_data["active_incidents"]
            total_incidents = self.network_data["total_incidents"]
            auto_healed = self.network_data["auto_healed"]
            
            print(f"📊 Status: {active_incidents} active, {total_incidents} total, {auto_healed} auto-healed")
            
            # Sleep before next cycle
            time.sleep(8)  # 8-second cycles for demo

    def start(self):
        """Start the simulation in a background thread."""
        if not self.running:
            self.running = True
            self.thread = threading.Thread(target=self.run_simulation, daemon=True)
            self.thread.start()
            return True
        return False

    def stop(self):
        """Stop the simulation."""
        self.running = False
        print("\n🛑 Simulation stopped")

    def get_incident_summary(self) -> Dict[str, Any]:
        """Get summary of all incidents."""
        active_incidents = [inc for inc in self.incidents if inc["status"] == "active"]
        resolved_incidents = [inc for inc in self.incidents if inc["status"] == "resolved"]
        
        return {
            "active_count": len(active_incidents),
            "resolved_count": len(resolved_incidents),
            "active_incidents": active_incidents,
            "recent_resolved": resolved_incidents[-5:] if resolved_incidents else []
        }

def main():
    """Main function for running the simulator."""
    simulator = LiveDemoSimulator()
    
    try:
        print("🎯 LiveOpsLab Demo Simulator")
        print("=" * 50)
        
        if simulator.start():
            print("✅ Simulation started! Check the dashboard for live updates.")
            print("🌐 Dashboard: http://localhost:8889")
            print("⚡ Updates every 8 seconds")
            print("🩹 Auto-healing enabled")
            print("\nPress Ctrl+C to stop the simulation...")
            
            # Keep main thread alive
            while simulator.running:
                time.sleep(1)
        else:
            print("❌ Failed to start simulation")
            
    except KeyboardInterrupt:
        simulator.stop()
        print("\n👋 Demo simulation ended")

if __name__ == "__main__":
    main()
