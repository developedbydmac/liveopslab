#!/usr/bin/env python3
"""
Integration module for LiveOpsLab access points and network infrastructure.
Provides functions to load and manage the generated network topology data.
"""

import json
import random
from typing import Dict, List, Any, Optional
from datetime import datetime, timedelta

class NetworkTopologyManager:
    """Manages access points and switch infrastructure for LiveOpsLab."""
    
    def __init__(self, topology_file: str = "network_topology.json"):
        """
        Initialize the network topology manager.
        
        Args:
            topology_file: Path to the network topology JSON file
        """
        self.topology_file = topology_file
        self.topology_data = self._load_topology()
        self.access_points = {ap["ap_id"]: ap for ap in self.topology_data["access_points"]}
        self.switches = self.topology_data["switches"]
    
    def _load_topology(self) -> Dict[str, Any]:
        """Load network topology from JSON file."""
        try:
            with open(self.topology_file, 'r') as f:
                return json.load(f)
        except FileNotFoundError:
            print(f"Warning: {self.topology_file} not found. Using empty topology.")
            return {"access_points": [], "switches": {}}
    
    def get_all_access_points(self) -> List[Dict[str, Any]]:
        """Get all access points."""
        return list(self.access_points.values())
    
    def get_access_point(self, ap_id: str) -> Optional[Dict[str, Any]]:
        """Get specific access point by ID."""
        return self.access_points.get(ap_id)
    
    def get_access_points_by_zone(self, zone: str) -> List[Dict[str, Any]]:
        """
        Get all access points that support a specific zone.
        
        Args:
            zone: Zone name (FanWiFi, VisitorWiFi, Backstage)
            
        Returns:
            List of access points with zone data
        """
        result = []
        for ap in self.access_points.values():
            if zone in ap.get("zones", {}):
                ap_copy = ap.copy()
                ap_copy["zone_data"] = ap_copy["zones"][zone]
                result.append(ap_copy)
        return result
    
    def get_switch_info(self, switch_id: str) -> Optional[Dict[str, Any]]:
        """Get switch information by ID."""
        return self.switches.get(switch_id)
    
    def get_all_switches(self) -> Dict[str, Dict[str, Any]]:
        """Get all switches."""
        return self.switches
    
    def simulate_outage(self, ap_id: str, zone: str, duration_minutes: int = 5) -> bool:
        """
        Simulate an outage for a specific AP zone.
        
        Args:
            ap_id: Access point ID
            zone: Zone name
            duration_minutes: How long the outage should last
            
        Returns:
            True if outage was simulated, False if AP/zone not found
        """
        if ap_id not in self.access_points:
            return False
        
        ap = self.access_points[ap_id]
        if zone not in ap.get("zones", {}):
            return False
        
        # Set zone to outage status
        ap["zones"][zone]["status"] = "outage"
        ap["zones"][zone]["outage_start"] = datetime.now().isoformat()
        ap["zones"][zone]["estimated_recovery"] = (
            datetime.now() + timedelta(minutes=duration_minutes)
        ).isoformat()
        ap["zones"][zone]["connected_clients"] = 0
        ap["zones"][zone]["throughput_mbps"] = 0.0
        
        return True
    
    def recover_zone(self, ap_id: str, zone: str) -> bool:
        """
        Recover a zone from outage.
        
        Args:
            ap_id: Access point ID
            zone: Zone name
            
        Returns:
            True if recovery was successful, False if AP/zone not found
        """
        if ap_id not in self.access_points:
            return False
        
        ap = self.access_points[ap_id]
        if zone not in ap.get("zones", {}):
            return False
        
        # Restore zone to healthy status
        zone_data = ap["zones"][zone]
        zone_data["status"] = "healthy"
        zone_data["latency_ms"] = random.randint(20, 60)
        zone_data["connected_clients"] = random.randint(0, 50)
        zone_data["throughput_mbps"] = round(random.uniform(10.5, 95.8), 1)
        zone_data["last_updated"] = datetime.now().isoformat()
        
        # Remove outage-specific fields
        zone_data.pop("outage_start", None)
        zone_data.pop("estimated_recovery", None)
        
        return True
    
    def get_zone_health_summary(self) -> Dict[str, Dict[str, Any]]:
        """
        Get health summary for all zones across all APs.
        
        Returns:
            Dictionary with zone health statistics
        """
        zones = ["FanWiFi", "VisitorWiFi", "Backstage"]
        summary = {}
        
        for zone in zones:
            zone_aps = self.get_access_points_by_zone(zone)
            
            if not zone_aps:
                continue
            
            healthy_count = sum(1 for ap in zone_aps 
                              if ap["zone_data"]["status"] == "healthy")
            outage_count = len(zone_aps) - healthy_count
            
            latencies = [ap["zone_data"]["latency_ms"] for ap in zone_aps 
                        if ap["zone_data"]["status"] == "healthy"]
            
            total_clients = sum(ap["zone_data"]["connected_clients"] 
                              for ap in zone_aps)
            
            avg_throughput = sum(ap["zone_data"]["throughput_mbps"] 
                               for ap in zone_aps) / len(zone_aps)
            
            summary[zone] = {
                "total_aps": len(zone_aps),
                "healthy_aps": healthy_count,
                "outage_aps": outage_count,
                "health_percentage": (healthy_count / len(zone_aps)) * 100,
                "avg_latency_ms": sum(latencies) / len(latencies) if latencies else 0,
                "total_connected_clients": total_clients,
                "avg_throughput_mbps": round(avg_throughput, 1)
            }
        
        return summary
    
    def get_switch_load_distribution(self) -> Dict[str, Dict[str, Any]]:
        """
        Get load distribution across switches.
        
        Returns:
            Dictionary with switch load information
        """
        switch_loads = {}
        
        for switch_id, switch_data in self.switches.items():
            connected_aps = len(switch_data.get("connected_aps", []))
            port_utilization = (connected_aps / switch_data.get("port_count", 24)) * 100
            
            switch_loads[switch_id] = {
                "connected_aps": connected_aps,
                "total_ports": switch_data.get("port_count", 24),
                "port_utilization_percentage": round(port_utilization, 1),
                "cpu_usage": switch_data.get("cpu_usage", 0),
                "memory_usage": switch_data.get("memory_usage", 0),
                "status": switch_data.get("status", "unknown")
            }
        
        return switch_loads
    
    def find_aps_by_criteria(self, **criteria) -> List[Dict[str, Any]]:
        """
        Find access points matching specific criteria.
        
        Args:
            **criteria: Key-value pairs to match (e.g., floor=2, section="North")
            
        Returns:
            List of matching access points
        """
        matching_aps = []
        
        for ap in self.access_points.values():
            match = True
            for key, value in criteria.items():
                if key in ap.get("location", {}):
                    if ap["location"][key] != value:
                        match = False
                        break
                elif key in ap.get("hardware", {}):
                    if ap["hardware"][key] != value:
                        match = False
                        break
                elif key in ap:
                    if ap[key] != value:
                        match = False
                        break
                else:
                    match = False
                    break
            
            if match:
                matching_aps.append(ap)
        
        return matching_aps

# Example usage and integration functions
def demo_network_operations():
    """Demonstrate network topology operations."""
    print("🏟️ LiveOpsLab Network Topology Demo")
    print("=" * 50)
    
    # Initialize topology manager
    topology = NetworkTopologyManager()
    
    print(f"📡 Total Access Points: {len(topology.get_all_access_points())}")
    print(f"🔌 Total Switches: {len(topology.get_all_switches())}")
    print()
    
    # Zone health summary
    print("🏥 Zone Health Summary:")
    health_summary = topology.get_zone_health_summary()
    for zone, stats in health_summary.items():
        print(f"  {zone}:")
        print(f"    - APs: {stats['healthy_aps']}/{stats['total_aps']} healthy ({stats['health_percentage']:.1f}%)")
        print(f"    - Avg Latency: {stats['avg_latency_ms']:.1f}ms")
        print(f"    - Connected Clients: {stats['total_connected_clients']}")
        print(f"    - Avg Throughput: {stats['avg_throughput_mbps']}Mbps")
    print()
    
    # Switch load distribution
    print("📊 Switch Load Distribution (Top 5):")
    switch_loads = topology.get_switch_load_distribution()
    sorted_switches = sorted(switch_loads.items(), 
                           key=lambda x: x[1]['port_utilization_percentage'], 
                           reverse=True)[:5]
    
    for switch_id, load_data in sorted_switches:
        print(f"  {switch_id}: {load_data['connected_aps']} APs "
              f"({load_data['port_utilization_percentage']:.1f}% utilization)")
    print()
    
    # Find APs by criteria
    print("🔍 Access Points on Floor 2:")
    floor2_aps = topology.find_aps_by_criteria(floor=2)
    for ap in floor2_aps[:3]:  # Show first 3
        print(f"  {ap['ap_id']}: {ap['location']['section']} section, "
              f"Switch: {ap['switch_id']}")
    
    print(f"  ... and {len(floor2_aps) - 3} more APs on floor 2")

if __name__ == "__main__":
    demo_network_operations()
