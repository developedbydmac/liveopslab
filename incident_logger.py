#!/usr/bin/env python3
"""
Incident logging and network state management for LiveOpsLab.
Handles incident simulation, logging, and network status updates.
"""

import json
import uuid
import random
from datetime import datetime
from typing import Dict, List, Any, Optional
from pathlib import Path

class IncidentLogger:
    """Manages incident logging and network state updates."""
    
    def __init__(self, 
                 network_topology_file: str = "network_topology.json",
                 incident_log_file: str = "incident_log.json"):
        self.network_topology_file = network_topology_file
        self.incident_log_file = incident_log_file
        self.network_data = self._load_network_data()
        self.incident_log = self._load_incident_log()
    
    def _load_network_data(self) -> Dict[str, Any]:
        """Load network topology data."""
        try:
            with open(self.network_topology_file, 'r') as f:
                return json.load(f)
        except FileNotFoundError:
            print(f"Warning: {self.network_topology_file} not found. Using empty network data.")
            return {"access_points": [], "switches": {}}
    
    def _load_incident_log(self) -> List[Dict[str, Any]]:
        """Load existing incident log or create empty list."""
        try:
            with open(self.incident_log_file, 'r') as f:
                return json.load(f)
        except FileNotFoundError:
            return []
    
    def _save_network_data(self):
        """Save updated network topology data."""
        with open(self.network_topology_file, 'w') as f:
            json.dump(self.network_data, f, indent=2)
    
    def _save_incident_log(self):
        """Save updated incident log."""
        with open(self.incident_log_file, 'w') as f:
            json.dump(self.incident_log, f, indent=2)
    
    def simulate_incident(self, ap_id: str, zone: str, issue_type: str) -> Dict[str, Any]:
        """
        Simulate an incident by updating zone status and logging the event.
        
        Args:
            ap_id: Access point ID (e.g., "AP-01")
            zone: Zone name (FanWiFi, VisitorWiFi, Backstage)
            issue_type: Type of issue (network, power, hardware, etc.)
            
        Returns:
            Dictionary with incident details and zone health snapshot
        """
        # Find the access point in network data
        ap_found = None
        for ap in self.network_data.get("access_points", []):
            if ap["ap_id"] == ap_id:
                ap_found = ap
                break
        
        if not ap_found:
            raise ValueError(f"Access point {ap_id} not found in network topology")
        
        if zone not in ap_found.get("zones", {}):
            raise ValueError(f"Zone {zone} not found in access point {ap_id}")
        
        # Generate incident ID and timestamp
        incident_id = str(uuid.uuid4())
        timestamp = datetime.now().isoformat()
        
        # Update zone status to "down"
        zone_data = ap_found["zones"][zone]
        previous_status = zone_data.get("status", "unknown")
        zone_data["status"] = "down"
        zone_data["incident_id"] = incident_id
        zone_data["incident_start"] = timestamp
        zone_data["issue_type"] = issue_type
        zone_data["connected_clients"] = 0  # Clients disconnected during outage
        zone_data["throughput_mbps"] = 0.0  # No throughput during outage
        
        # Create incident log entry
        incident_entry = {
            "id": incident_id,
            "timestamp": timestamp,
            "ap_id": ap_id,
            "zone": zone,
            "issue_type": issue_type,
            "status": "down",
            "previous_status": previous_status,
            "switch_id": ap_found.get("switch_id"),
            "location": ap_found.get("location", {}),
            "resolved": False,
            "resolution_timestamp": None
        }
        
        # Add to incident log
        self.incident_log.append(incident_entry)
        
        # Save updated data
        self._save_network_data()
        self._save_incident_log()
        
        # Generate zone health snapshot
        zone_health = self._get_zone_health_snapshot(zone)
        
        return {
            "incident_id": incident_id,
            "status": "incident_simulated",
            "message": f"Simulated {issue_type} incident for {ap_id} zone {zone}",
            "incident_details": incident_entry,
            "zone_health_snapshot": zone_health
        }
    
    def resolve_incident(self, incident_id: str) -> Dict[str, Any]:
        """
        Resolve an incident by restoring zone status.
        
        Args:
            incident_id: UUID of the incident to resolve
            
        Returns:
            Dictionary with resolution details
        """
        # Find incident in log
        incident = None
        for inc in self.incident_log:
            if inc["id"] == incident_id:
                incident = inc
                break
        
        if not incident:
            raise ValueError(f"Incident {incident_id} not found")
        
        if incident["resolved"]:
            return {
                "status": "already_resolved",
                "message": f"Incident {incident_id} was already resolved",
                "resolution_timestamp": incident["resolution_timestamp"]
            }
        
        # Find the affected AP and zone
        ap_id = incident["ap_id"]
        zone = incident["zone"]
        
        ap_found = None
        for ap in self.network_data.get("access_points", []):
            if ap["ap_id"] == ap_id:
                ap_found = ap
                break
        
        if ap_found and zone in ap_found.get("zones", {}):
            zone_data = ap_found["zones"][zone]
            
            # Restore zone to healthy status
            zone_data["status"] = "healthy"
            zone_data.pop("incident_id", None)
            zone_data.pop("incident_start", None)
            zone_data.pop("issue_type", None)
            
            # Restore realistic values
            import random
            zone_data["latency_ms"] = random.randint(20, 60)
            zone_data["connected_clients"] = random.randint(0, 50)
            zone_data["throughput_mbps"] = round(random.uniform(10.5, 95.8), 1)
            zone_data["last_updated"] = datetime.now().isoformat()
        
        # Update incident log
        incident["resolved"] = True
        incident["resolution_timestamp"] = datetime.now().isoformat()
        
        # Save updated data
        self._save_network_data()
        self._save_incident_log()
        
        return {
            "status": "resolved",
            "message": f"Resolved incident {incident_id} for {ap_id} zone {zone}",
            "incident_id": incident_id,
            "resolution_timestamp": incident["resolution_timestamp"]
        }
    
    def _get_zone_health_snapshot(self, zone: str) -> Dict[str, Any]:
        """
        Get health snapshot for a specific zone across all APs.
        
        Args:
            zone: Zone name to analyze
            
        Returns:
            Zone health statistics
        """
        zone_aps = []
        for ap in self.network_data.get("access_points", []):
            if zone in ap.get("zones", {}):
                zone_aps.append({
                    "ap_id": ap["ap_id"],
                    "status": ap["zones"][zone]["status"],
                    "switch_id": ap.get("switch_id"),
                    "location": ap.get("location", {})
                })
        
        if not zone_aps:
            return {"error": f"No access points found for zone {zone}"}
        
        healthy_count = sum(1 for ap in zone_aps if ap["status"] == "healthy")
        down_count = len(zone_aps) - healthy_count
        
        return {
            "zone": zone,
            "total_aps": len(zone_aps),
            "healthy_aps": healthy_count,
            "down_aps": down_count,
            "health_percentage": (healthy_count / len(zone_aps)) * 100,
            "timestamp": datetime.now().isoformat(),
            "affected_aps": [ap for ap in zone_aps if ap["status"] != "healthy"]
        }
    
    def get_active_incidents(self) -> List[Dict[str, Any]]:
        """Get all unresolved incidents."""
        return [inc for inc in self.incident_log if not inc.get("resolved", False)]
    
    def get_incident_history(self, limit: int = 50) -> List[Dict[str, Any]]:
        """Get recent incident history."""
        # Sort by timestamp, most recent first
        sorted_incidents = sorted(
            self.incident_log, 
            key=lambda x: x["timestamp"], 
            reverse=True
        )
        return sorted_incidents[:limit]
    
    def get_zone_incidents(self, zone: str) -> List[Dict[str, Any]]:
        """Get all incidents for a specific zone."""
        return [inc for inc in self.incident_log if inc["zone"] == zone]
    
    def get_ap_incidents(self, ap_id: str) -> List[Dict[str, Any]]:
        """Get all incidents for a specific access point."""
        return [inc for inc in self.incident_log if inc["ap_id"] == ap_id]
    
    def generate_root_cause(self, ap_id: str, zone: str, issue_type: str) -> Dict[str, Any]:
        """
        Generate root cause analysis for an incident.
        
        Args:
            ap_id: Access point ID (e.g., "AP-01")
            zone: Zone name (FanWiFi, VisitorWiFi, Backstage)
            issue_type: Type of issue (network_connectivity, power_failure, etc.)
            
        Returns:
            JSON response with root cause analysis
        """
        # Find the access point for context
        ap_found = None
        for ap in self.network_data.get("access_points", []):
            if ap["ap_id"] == ap_id:
                ap_found = ap
                break
        
        if not ap_found:
            return {
                "error": f"Access point {ap_id} not found",
                "ap_id": ap_id,
                "zone": zone,
                "issue_type": issue_type
            }
        
        # Get AP context
        switch_id = ap_found.get("switch_id", "Unknown")
        location = ap_found.get("location", {})
        hardware = ap_found.get("hardware", {})
        
        # Root cause analysis based on issue type
        root_cause_analysis = self._analyze_root_cause(
            issue_type, ap_id, zone, switch_id, location, hardware
        )
        
        return {
            "ap_id": ap_id,
            "zone": zone,
            "issue_type": issue_type,
            "switch_id": switch_id,
            "location": location,
            "hardware_model": hardware.get("model", "Unknown"),
            "root_cause": root_cause_analysis["root_cause"],
            "fix_suggestion": root_cause_analysis["fix_suggestion"],
            "estimated_recovery_seconds": root_cause_analysis["estimated_recovery_seconds"],
            "confidence_level": root_cause_analysis["confidence_level"],
            "additional_context": root_cause_analysis["additional_context"],
            "troubleshooting_steps": root_cause_analysis["troubleshooting_steps"],
            "timestamp": datetime.now().isoformat()
        }
    
    def _analyze_root_cause(self, issue_type: str, ap_id: str, zone: str, 
                           switch_id: str, location: Dict, hardware: Dict) -> Dict[str, Any]:
        """
        Internal method to analyze root cause based on issue type and context.
        
        Returns:
            Dictionary with root cause analysis details
        """
        # Base analysis templates by issue type
        analysis_templates = {
            "network_connectivity": {
                "root_causes": [
                    "Signal degradation due to interference",
                    "Network cable disconnection or damage",
                    "Switch port failure or configuration issue",
                    "IP address conflict or DHCP exhaustion",
                    "Upstream network congestion"
                ],
                "fix_suggestions": [
                    "Restart access point to refresh network stack",
                    "Check and reseat network cables",
                    "Reboot switch port or check switch configuration",
                    "Verify IP configuration and DHCP pool",
                    "Analyze network traffic patterns"
                ],
                "recovery_range": (30, 180),  # 30 seconds to 3 minutes
                "confidence_base": 75
            },
            "power_failure": {
                "root_causes": [
                    "Power budget exceeded on PoE switch",
                    "Faulty PoE injector or power adapter", 
                    "Power supply unit failure",
                    "Circuit breaker trip or electrical fault",
                    "PoE cable degradation or damage"
                ],
                "fix_suggestions": [
                    "Check PoE power budget and redistribute load",
                    "Replace PoE injector or power adapter",
                    "Inspect power supply unit connections",
                    "Reset circuit breaker and check electrical panel",
                    "Test and replace PoE network cable"
                ],
                "recovery_range": (60, 300),  # 1 to 5 minutes
                "confidence_base": 85
            },
            "hardware_malfunction": {
                "root_causes": [
                    "Radio module failure or overheating",
                    "Memory corruption or firmware crash",
                    "Antenna damage or connector issues",
                    "Environmental damage (moisture, heat)",
                    "Component aging or manufacturing defect"
                ],
                "fix_suggestions": [
                    "Reboot AP to reset radio modules",
                    "Update firmware to latest stable version",
                    "Inspect antenna connections and replace if needed",
                    "Check environmental conditions and ventilation",
                    "Schedule hardware replacement if persistent"
                ],
                "recovery_range": (120, 600),  # 2 to 10 minutes
                "confidence_base": 70
            },
            "high_latency": {
                "root_causes": [
                    "RF interference from nearby devices",
                    "Channel congestion or poor channel selection",
                    "Backhaul bandwidth saturation",
                    "CPU overload on access point",
                    "QoS misconfiguration or traffic shaping"
                ],
                "fix_suggestions": [
                    "Perform RF spectrum analysis and optimize channels",
                    "Enable automatic channel selection and width optimization",
                    "Upgrade backhaul capacity or load balance traffic",
                    "Monitor AP CPU usage and optimize configuration",
                    "Review and adjust QoS policies"
                ],
                "recovery_range": (45, 240),  # 45 seconds to 4 minutes
                "confidence_base": 65
            },
            "authentication_failure": {
                "root_causes": [
                    "RADIUS server connectivity issues",
                    "Certificate expiration or validation failure",
                    "Active Directory synchronization problems",
                    "Captive portal service malfunction",
                    "802.1X configuration mismatch"
                ],
                "fix_suggestions": [
                    "Verify RADIUS server connectivity and credentials",
                    "Check certificate validity and renewal status",
                    "Restart Active Directory services and sync",
                    "Restart captive portal service and database",
                    "Review 802.1X configuration on AP and switch"
                ],
                "recovery_range": (90, 420),  # 1.5 to 7 minutes
                "confidence_base": 80
            }
        }
        
        # Get template for issue type, default to network_connectivity
        template = analysis_templates.get(issue_type, analysis_templates["network_connectivity"])
        
        # Select root cause based on context
        root_cause = self._select_contextual_root_cause(
            template["root_causes"], ap_id, zone, switch_id, location, hardware
        )
        
        # Select corresponding fix suggestion
        fix_index = template["root_causes"].index(root_cause)
        fix_suggestion = template["fix_suggestions"][fix_index]
        
        # Calculate estimated recovery time
        min_time, max_time = template["recovery_range"]
        estimated_recovery = random.randint(min_time, max_time)
        
        # Adjust recovery time based on zone (backstage gets priority)
        if zone == "Backstage":
            estimated_recovery = int(estimated_recovery * 0.7)  # 30% faster for critical zones
        elif zone == "FanWiFi":
            estimated_recovery = int(estimated_recovery * 1.2)  # 20% slower for public WiFi
        
        # Calculate confidence level
        confidence = self._calculate_confidence(
            template["confidence_base"], issue_type, location, hardware
        )
        
        # Generate additional context
        additional_context = self._generate_additional_context(
            ap_id, zone, switch_id, location, hardware, issue_type
        )
        
        # Generate troubleshooting steps
        troubleshooting_steps = self._generate_troubleshooting_steps(
            issue_type, fix_suggestion, ap_id, switch_id
        )
        
        return {
            "root_cause": root_cause,
            "fix_suggestion": fix_suggestion,
            "estimated_recovery_seconds": estimated_recovery,
            "confidence_level": confidence,
            "additional_context": additional_context,
            "troubleshooting_steps": troubleshooting_steps
        }
    
    def _select_contextual_root_cause(self, root_causes: List[str], ap_id: str, 
                                    zone: str, switch_id: str, location: Dict, 
                                    hardware: Dict) -> str:
        """Select most likely root cause based on context."""
        
        # Contextual selection logic
        floor = location.get("floor", 1)
        section = location.get("section", "Unknown")
        model = hardware.get("model", "Unknown")
        
        # Bias selection based on context
        if floor >= 3:  # Higher floors more prone to signal issues
            if "Signal degradation" in " ".join(root_causes):
                return next(rc for rc in root_causes if "Signal degradation" in rc)
        
        if "Cisco" in model and "switch" in " ".join(root_causes).lower():
            # Cisco hardware more likely to have switch-related issues
            switch_causes = [rc for rc in root_causes if "switch" in rc.lower()]
            if switch_causes:
                return switch_causes[0]
        
        if zone == "Backstage" and "power" in " ".join(root_causes).lower():
            # Backstage areas often have power issues due to high-power equipment
            power_causes = [rc for rc in root_causes if "power" in rc.lower()]
            if power_causes:
                return power_causes[0]
        
        # Default to random selection weighted by likelihood
        return random.choice(root_causes)
    
    def _calculate_confidence(self, base_confidence: int, issue_type: str, 
                            location: Dict, hardware: Dict) -> int:
        """Calculate confidence level for root cause analysis."""
        
        confidence = base_confidence
        
        # Adjust based on available context
        if location.get("floor") and location.get("section"):
            confidence += 5  # More context = higher confidence
        
        if hardware.get("model") and hardware.get("uptime_hours"):
            confidence += 5  # Hardware details available
        
        # Adjust based on issue type complexity
        complex_issues = ["hardware_malfunction", "authentication_failure"]
        if issue_type in complex_issues:
            confidence -= 10  # Complex issues are harder to diagnose
        
        # Ensure confidence is within valid range
        return max(50, min(95, confidence))
    
    def _generate_additional_context(self, ap_id: str, zone: str, switch_id: str,
                                   location: Dict, hardware: Dict, issue_type: str) -> Dict[str, Any]:
        """Generate additional context for the root cause analysis."""
        
        context = {
            "environmental_factors": [],
            "historical_patterns": [],
            "network_topology": {
                "switch_load": "Normal",
                "adjacent_aps": "Operational",
                "backhaul_status": "Healthy"
            }
        }
        
        # Environmental factors based on location
        floor = location.get("floor", 1)
        section = location.get("section", "Unknown")
        
        if floor >= 3:
            context["environmental_factors"].append("High floor - potential signal interference")
        
        if section in ["North", "South"]:
            context["environmental_factors"].append("Perimeter location - external interference possible")
        
        # Historical patterns (simulated)
        uptime_hours = hardware.get("uptime_hours", 0)
        if uptime_hours > 6000:  # ~8 months
            context["historical_patterns"].append("Long uptime - potential for memory leaks")
        
        if issue_type == "network_connectivity":
            context["historical_patterns"].append("Similar incidents reported during peak hours")
        
        return context
    
    def _generate_troubleshooting_steps(self, issue_type: str, fix_suggestion: str,
                                      ap_id: str, switch_id: str) -> List[str]:
        """Generate step-by-step troubleshooting instructions."""
        
        base_steps = [
            f"1. Access {ap_id} management interface via SSH or web GUI",
            f"2. Check system logs for error messages related to {issue_type}",
            f"3. Verify network connectivity to {switch_id}",
        ]
        
        # Issue-specific steps
        if issue_type == "network_connectivity":
            specific_steps = [
                "4. Test ping connectivity to gateway and DNS servers",
                "5. Check interface statistics for packet drops or errors",
                "6. Verify VLAN configuration and port settings"
            ]
        elif issue_type == "power_failure":
            specific_steps = [
                "4. Check PoE status and power consumption on switch",
                "5. Measure power delivery using cable tester",
                "6. Verify power budget allocation on switch"
            ]
        elif issue_type == "hardware_malfunction":
            specific_steps = [
                "4. Check system temperature and fan status",
                "5. Run hardware diagnostics and memory test",
                "6. Inspect physical connections and antenna status"
            ]
        else:
            specific_steps = [
                "4. Review configuration settings for anomalies",
                "5. Check service status and restart if needed",
                "6. Monitor system resources and performance metrics"
            ]
        
        # Recovery steps
        recovery_steps = [
            f"7. Execute fix: {fix_suggestion}",
            "8. Monitor system for 5-10 minutes to confirm stability",
            "9. Update incident log with resolution details"
        ]
        
        return base_steps + specific_steps + recovery_steps

def demo_incident_simulation():
    """Demonstrate incident simulation and logging."""
    print("🚨 LiveOpsLab Incident Simulation Demo")
    print("=" * 50)
    
    # Initialize incident logger
    logger = IncidentLogger()
    
    print("📊 Network Status Before Incident:")
    fanwifi_health = logger._get_zone_health_snapshot("FanWiFi")
    print(f"  FanWiFi: {fanwifi_health['healthy_aps']}/{fanwifi_health['total_aps']} healthy")
    print()
    
    # Test root cause analysis first
    print("🔍 Root Cause Analysis Demo:")
    test_scenarios = [
        {"ap_id": "AP-01", "zone": "FanWiFi", "issue_type": "network_connectivity"},
        {"ap_id": "AP-12", "zone": "Backstage", "issue_type": "power_failure"},
        {"ap_id": "AP-25", "zone": "VisitorWiFi", "issue_type": "hardware_malfunction"}
    ]
    
    for scenario in test_scenarios:
        print(f"\n  📡 Analyzing {scenario['ap_id']} - {scenario['zone']} - {scenario['issue_type']}:")
        analysis = logger.generate_root_cause(
            scenario["ap_id"], 
            scenario["zone"], 
            scenario["issue_type"]
        )
        
        if "error" not in analysis:
            print(f"     🎯 Root Cause: {analysis['root_cause']}")
            print(f"     🔧 Fix: {analysis['fix_suggestion']}")
            print(f"     ⏱️  Recovery Time: {analysis['estimated_recovery_seconds']}s")
            print(f"     📊 Confidence: {analysis['confidence_level']}%")
        else:
            print(f"     ❌ {analysis['error']}")
    
    print("\n" + "=" * 50)
    
    # Simulate an incident
    print("⚠️  Simulating Network Incident...")
    try:
        result = logger.simulate_incident("AP-01", "FanWiFi", "network_connectivity")
        print(f"  ✅ Incident created: {result['incident_id']}")
        print(f"  📝 Message: {result['message']}")
        print()
        
        # Show updated health
        print("📊 Network Status After Incident:")
        updated_health = result['zone_health_snapshot']
        print(f"  FanWiFi: {updated_health['healthy_aps']}/{updated_health['total_aps']} healthy")
        print(f"  Health: {updated_health['health_percentage']:.1f}%")
        print()
        
        # Show active incidents
        active_incidents = logger.get_active_incidents()
        print(f"🔥 Active Incidents: {len(active_incidents)}")
        for inc in active_incidents[-3:]:  # Show last 3
            print(f"  - {inc['id'][:8]}... | {inc['ap_id']} | {inc['zone']} | {inc['issue_type']}")
        print()
        
        # Resolve the incident
        print("🔧 Resolving Incident...")
        resolution = logger.resolve_incident(result['incident_id'])
        print(f"  ✅ {resolution['message']}")
        
    except Exception as e:
        print(f"  ❌ Error: {e}")

if __name__ == "__main__":
    demo_incident_simulation()
