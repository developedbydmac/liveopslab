#!/usr/bin/env python3
"""
Command-line interface for LiveOpsLab Network Dashboard.
Allows testing incidents and monitoring network status.
"""

import json
import argparse
import requests
import time
from datetime import datetime
from incident_logger import IncidentLogger

def send_alert(ap_id, zone, issue_type, root_cause, fix_suggestion, webhook_url=None, platform="slack"):
    """
    Send alert notification to Slack or Discord webhook.
    
    Args:
        ap_id: Access point ID
        zone: Zone name
        issue_type: Type of issue
        root_cause: Root cause analysis
        fix_suggestion: Recommended fix
        webhook_url: Webhook URL for notifications
        platform: 'slack' or 'discord'
    """
    if not webhook_url:
        print("⚠️ No webhook URL configured - alert not sent")
        return False
    
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    # Map issue types to emojis
    issue_emojis = {
        "network_connectivity": "🌐",
        "power_failure": "⚡",
        "hardware_malfunction": "🔧",
        "high_latency": "🐌",
        "authentication_failure": "🔐"
    }
    
    zone_emojis = {
        "FanWiFi": "🏟️",
        "VisitorWiFi": "👥", 
        "Backstage": "🎭"
    }
    
    issue_emoji = issue_emojis.get(issue_type, "⚠️")
    zone_emoji = zone_emojis.get(zone, "📡")
    
    if platform.lower() == "slack":
        payload = {
            "text": f"🚨 *LiveOpsLab Network Alert* 🚨",
            "attachments": [
                {
                    "color": "danger",
                    "fields": [
                        {
                            "title": f"{issue_emoji} Incident Details",
                            "value": f"*AP:* {ap_id}\n*Zone:* {zone_emoji} {zone}\n*Issue:* {issue_type.replace('_', ' ').title()}",
                            "short": True
                        },
                        {
                            "title": "🔍 Root Cause",
                            "value": root_cause,
                            "short": True
                        },
                        {
                            "title": "🔧 Recommended Fix",
                            "value": fix_suggestion,
                            "short": False
                        },
                        {
                            "title": "⏰ Timestamp",
                            "value": timestamp,
                            "short": True
                        }
                    ],
                    "footer": "LiveOpsLab Network Monitoring",
                    "footer_icon": "https://emoji.slack-edge.com/T123456/network/1234567890.png"
                }
            ]
        }
    else:  # Discord
        payload = {
            "embeds": [
                {
                    "title": "🚨 LiveOpsLab Network Alert",
                    "description": f"{issue_emoji} **{issue_type.replace('_', ' ').title()}** incident detected",
                    "color": 15158332,  # Red color
                    "fields": [
                        {
                            "name": "📡 Access Point",
                            "value": ap_id,
                            "inline": True
                        },
                        {
                            "name": f"{zone_emoji} Affected Zone", 
                            "value": zone,
                            "inline": True
                        },
                        {
                            "name": "🔍 Root Cause",
                            "value": root_cause,
                            "inline": False
                        },
                        {
                            "name": "🔧 Recommended Fix",
                            "value": fix_suggestion,
                            "inline": False
                        }
                    ],
                    "timestamp": datetime.now().isoformat(),
                    "footer": {
                        "text": "LiveOpsLab Network Monitoring"
                    }
                }
            ]
        }
    
    try:
        response = requests.post(webhook_url, json=payload, timeout=10)
        response.raise_for_status()
        print(f"✅ Alert sent to {platform.title()} successfully")
        return True
    except requests.exceptions.RequestException as e:
        print(f"❌ Failed to send {platform} alert: {e}")
        return False

class DashboardCLI:
    """Command-line interface for the network dashboard."""
    
    def __init__(self, base_url="http://localhost:8888", webhook_url=None, webhook_platform="slack"):
        self.base_url = base_url
        self.webhook_url = webhook_url
        self.webhook_platform = webhook_platform
        self.incident_logger = IncidentLogger()
    
    def check_server_status(self):
        """Check if the dashboard server is running."""
        try:
            response = requests.get(f"{self.base_url}/network_topology.json", timeout=5)
            return response.status_code == 200
        except requests.exceptions.RequestException:
            return False
    
    def simulate_incident(self, ap_id=None, zone=None, issue_type=None):
        """Simulate a network incident."""
        try:
            if not ap_id:
                import random
                ap_id = f"AP-{random.randint(1, 50):02d}"
            
            if not zone:
                import random
                zone = random.choice(["FanWiFi", "VisitorWiFi", "Backstage"])
            
            if not issue_type:
                import random
                issue_type = random.choice([
                    "network_connectivity", "power_failure", "hardware_malfunction",
                    "high_latency", "authentication_failure"
                ])
            
            print(f"🚨 Simulating {issue_type} incident on {ap_id} - {zone}")
            
            # Use local incident logger
            result = self.incident_logger.simulate_incident(ap_id, zone, issue_type)
            
            print(f"✅ Incident created: {result['incident_id']}")
            print(f"📝 {result['message']}")
            
            # Generate root cause analysis
            root_cause = self.incident_logger.generate_root_cause(ap_id, zone, issue_type)
            
            print(f"\n🔍 Root Cause Analysis:")
            print(f"  🎯 Cause: {root_cause['root_cause']}")
            print(f"  🔧 Fix: {root_cause['fix_suggestion']}")
            print(f"  ⏱️  Recovery: {root_cause['estimated_recovery_seconds']}s")
            print(f"  📊 Confidence: {root_cause['confidence_level']}%")
            
            # Send alert if webhook is configured
            if self.webhook_url:
                print(f"\n📢 Sending alert to {self.webhook_platform.title()}...")
                send_alert(
                    ap_id=ap_id,
                    zone=zone,
                    issue_type=issue_type,
                    root_cause=root_cause['root_cause'],
                    fix_suggestion=root_cause['fix_suggestion'],
                    webhook_url=self.webhook_url,
                    platform=self.webhook_platform
                )
            
            return result['incident_id']
            
        except Exception as e:
            print(f"❌ Error simulating incident: {e}")
            return None
    
    def resolve_incident(self, incident_id):
        """Resolve a network incident."""
        try:
            print(f"🔧 Resolving incident {incident_id[:8]}...")
            
            result = self.incident_logger.resolve_incident(incident_id)
            
            print(f"✅ {result['message']}")
            
        except Exception as e:
            print(f"❌ Error resolving incident: {e}")
    
    def replay_incident(self, incident_id):
        """Replay a past incident by ID."""
        try:
            # Load incident history from incident_log.json
            incident_log = self.incident_logger.get_incident_history(limit=1000)
            
            # Find the incident by ID
            target_incident = None
            for incident in incident_log:
                if incident['id'] == incident_id or incident['id'].startswith(incident_id):
                    target_incident = incident
                    break
            
            if not target_incident:
                print(f"❌ Incident {incident_id} not found in history")
                return None
            
            print(f"🔄 Replaying incident {target_incident['id'][:8]}...")
            print(f"📅 Original timestamp: {target_incident['timestamp']}")
            print(f"📡 Original details: {target_incident['ap_id']} - {target_incident['zone']} - {target_incident['issue_type']}")
            
            # Re-simulate the same incident
            new_incident_id = self.simulate_incident(
                ap_id=target_incident['ap_id'],
                zone=target_incident['zone'], 
                issue_type=target_incident['issue_type']
            )
            
            if new_incident_id:
                print(f"✅ Incident replayed with new ID: {new_incident_id}")
                return new_incident_id
            else:
                print(f"❌ Failed to replay incident")
                return None
                
        except Exception as e:
            print(f"❌ Error replaying incident: {e}")
            return None
    
    def show_ap_status(self, ap_id):
        """Show status for all 3 zones of a specific AP."""
        try:
            # Load network topology
            if hasattr(self.incident_logger, 'network_data') and self.incident_logger.network_data:
                network_data = self.incident_logger.network_data
            else:
                # Try to load from file
                try:
                    with open('network_topology.json', 'r') as f:
                        network_data = json.load(f)
                except FileNotFoundError:
                    print(f"❌ Network topology file not found")
                    return
            
            # Find the specific AP
            target_ap = None
            for ap in network_data.get('access_points', []):
                if ap['ap_id'] == ap_id:
                    target_ap = ap
                    break
            
            if not target_ap:
                print(f"❌ Access Point {ap_id} not found")
                return
            
            print(f"📡 Access Point Status: {ap_id}")
            print("=" * 50)
            
            # AP details  
            print(f"🔌 Switch: {target_ap.get('switch_id', 'Unknown')}")
            print(f"🏢 Location: Floor {target_ap.get('location', {}).get('floor', '?')} - {target_ap.get('location', {}).get('section', 'Unknown')}")
            print(f"💻 Hardware: {target_ap.get('hardware', {}).get('model', 'Unknown')}")
            print(f"🌐 IP Address: {target_ap.get('network', {}).get('ip_address', 'Unknown')}")
            print()
            
            # Zone status
            zones = ["FanWiFi", "VisitorWiFi", "Backstage"]
            zone_emojis = {"FanWiFi": "🏟️", "VisitorWiFi": "👥", "Backstage": "🎭"}
            
            for zone in zones:
                if zone in target_ap.get('zones', {}):
                    zone_data = target_ap['zones'][zone]
                    status = zone_data.get('status', 'unknown')
                    
                    # Status icon
                    if status == 'healthy':
                        status_icon = "🟢"
                        status_color = "Healthy"
                    elif status == 'warning':
                        status_icon = "🟡"
                        status_color = "Warning" 
                    else:
                        status_icon = "🔴"
                        status_color = "Down"
                    
                    print(f"{zone_emojis.get(zone, '📶')} {zone}:")
                    print(f"   Status: {status_icon} {status_color}")
                    print(f"   Latency: {zone_data.get('latency_ms', 'N/A')}ms")
                    print(f"   Clients: {zone_data.get('connected_clients', 0)}")
                    print(f"   Throughput: {zone_data.get('throughput_mbps', 0.0)} Mbps")
                    print(f"   Signal: {zone_data.get('signal_strength_dbm', 'N/A')} dBm")
                    print(f"   Channel: {zone_data.get('channel', 'N/A')}")
                    print(f"   Updated: {zone_data.get('last_updated', 'Never')[:19]}")
                    print()
                else:
                    print(f"{zone_emojis.get(zone, '📶')} {zone}: ❌ Not configured")
                    print()
            
            # Check for active incidents on this AP
            active_incidents = [inc for inc in self.incident_logger.get_active_incidents() 
                             if inc['ap_id'] == ap_id]
            
            if active_incidents:
                print(f"🚨 Active Incidents on {ap_id}:")
                for incident in active_incidents:
                    age = self.calculate_incident_age(incident['timestamp'])
                    print(f"   🔥 {incident['id'][:8]} | {incident['zone']} | {incident['issue_type']} | {age}")
            else:
                print(f"✅ No active incidents on {ap_id}")
                
        except Exception as e:
            print(f"❌ Error getting AP status: {e}")
    
    def show_network_status(self):
        """Display current network status."""
        try:
            # Check server status
            server_online = self.check_server_status()
            
            print("🌐 LiveOpsLab Network Status")
            print("=" * 50)
            print(f"Dashboard Server: {'🟢 Online' if server_online else '🔴 Offline'}")
            
            if server_online:
                print(f"Dashboard URL: {self.base_url}")
            
            # Show zone health
            zones = ["FanWiFi", "VisitorWiFi", "Backstage"]
            
            for zone in zones:
                health = self.incident_logger._get_zone_health_snapshot(zone)
                if "error" not in health:
                    health_pct = health["health_percentage"]
                    status_icon = "🟢" if health_pct >= 80 else "🟡" if health_pct >= 50 else "🔴"
                    
                    print(f"{status_icon} {zone}: {health['healthy_aps']}/{health['total_aps']} healthy ({health_pct:.1f}%)")
                    
                    if health["affected_aps"]:
                        print(f"   ⚠️ Affected APs: {', '.join([ap['ap_id'] for ap in health['affected_aps']])}")
            
            # Show active incidents
            active_incidents = self.incident_logger.get_active_incidents()
            
            print(f"\n🔥 Active Incidents: {len(active_incidents)}")
            
            for incident in active_incidents[-5:]:  # Show last 5
                age = self.calculate_incident_age(incident["timestamp"])
                print(f"   🚨 {incident['id'][:8]} | {incident['ap_id']} | {incident['zone']} | {incident['issue_type']} | {age}")
            
        except Exception as e:
            print(f"❌ Error getting network status: {e}")
    
    def calculate_incident_age(self, timestamp_str):
        """Calculate how long ago an incident occurred."""
        try:
            incident_time = datetime.fromisoformat(timestamp_str.replace('Z', '+00:00'))
            now = datetime.now(incident_time.tzinfo)
            age = now - incident_time
            
            if age.days > 0:
                return f"{age.days}d ago"
            elif age.seconds > 3600:
                return f"{age.seconds // 3600}h ago"
            elif age.seconds > 60:
                return f"{age.seconds // 60}m ago"
            else:
                return f"{age.seconds}s ago"
        except:
            return "unknown age"
    
    def monitor_network(self, duration=60):
        """Monitor network status in real-time."""
        print(f"📊 Monitoring network for {duration} seconds...")
        print("Press Ctrl+C to stop")
        
        try:
            start_time = time.time()
            
            while time.time() - start_time < duration:
                # Clear screen (simple version)
                print("\n" * 3)
                print(f"🕐 {datetime.now().strftime('%H:%M:%S')} - Network Monitor")
                print("-" * 40)
                
                self.show_network_status()
                
                # Wait 10 seconds before next update
                time.sleep(10)
                
        except KeyboardInterrupt:
            print("\n🛑 Monitoring stopped by user")
    
    def demo_scenario(self):
        """Run a demonstration scenario."""
        print("🎭 Running LiveOpsLab Demo Scenario")
        print("=" * 50)
        
        # Initial status
        print("📊 Initial Network Status:")
        self.show_network_status()
        
        # Simulate multiple incidents
        print(f"\n⚠️ Simulating multiple incidents...")
        
        incidents = []
        
        # Scenario 1: Power issue in backstage
        incident_id = self.simulate_incident("AP-15", "Backstage", "power_failure")
        if incident_id:
            incidents.append(incident_id)
        
        time.sleep(2)
        
        # Scenario 2: Network connectivity issue in fan area
        incident_id = self.simulate_incident("AP-08", "FanWiFi", "network_connectivity")
        if incident_id:
            incidents.append(incident_id)
        
        time.sleep(2)
        
        # Scenario 3: Hardware malfunction in visitor area
        incident_id = self.simulate_incident("AP-32", "VisitorWiFi", "hardware_malfunction")
        if incident_id:
            incidents.append(incident_id)
        
        # Show updated status
        print(f"\n📊 Network Status After Incidents:")
        self.show_network_status()
        
        # Wait a moment
        print(f"\n⏳ Waiting 5 seconds before resolution...")
        time.sleep(5)
        
        # Resolve incidents
        print(f"\n🔧 Resolving incidents...")
        for incident_id in incidents:
            self.resolve_incident(incident_id)
            time.sleep(1)
        
        # Final status
        print(f"\n📊 Final Network Status:")
        self.show_network_status()
        
        print(f"\n🎉 Demo scenario completed!")

def main():
    """Main CLI function."""
    parser = argparse.ArgumentParser(description="LiveOpsLab Network Dashboard CLI")
    parser.add_argument("--url", default="http://localhost:8888", help="Dashboard server URL")
    parser.add_argument("--webhook", help="Slack/Discord webhook URL for alerts")
    parser.add_argument("--platform", choices=["slack", "discord"], default="slack", help="Webhook platform")
    
    subparsers = parser.add_subparsers(dest="command", help="Available commands")
    
    # Status command (network overview)
    subparsers.add_parser("status", help="Show overall network status")
    
    # AP Status command (specific AP)
    ap_status_parser = subparsers.add_parser("ap-status", help="Show status for all 3 zones of a specific AP")
    ap_status_parser.add_argument("ap_id", help="Access Point ID (e.g., AP-01)")
    
    # Simulate incident command
    simulate_parser = subparsers.add_parser("simulate", help="Simulate an incident")
    simulate_parser.add_argument("--ap", help="Access Point ID (e.g., AP-01)")
    simulate_parser.add_argument("--zone", choices=["FanWiFi", "VisitorWiFi", "Backstage"], help="Zone name")
    simulate_parser.add_argument("--issue", choices=[
        "network_connectivity", "power_failure", "hardware_malfunction", 
        "high_latency", "authentication_failure"
    ], help="Issue type")
    
    # Replay incident command
    replay_parser = subparsers.add_parser("replay", help="Replay a past incident by ID")
    replay_parser.add_argument("incident_id", help="Incident ID to replay (full ID or first 8 characters)")
    
    # Resolve incident command
    resolve_parser = subparsers.add_parser("resolve", help="Resolve an incident")
    resolve_parser.add_argument("incident_id", help="Incident ID to resolve")
    
    # Monitor command
    monitor_parser = subparsers.add_parser("monitor", help="Monitor network in real-time")
    monitor_parser.add_argument("--duration", type=int, default=60, help="Monitoring duration in seconds")
    
    # Demo command
    subparsers.add_parser("demo", help="Run demonstration scenario")
    
    args = parser.parse_args()
    
    cli = DashboardCLI(args.url, args.webhook, args.platform)
    
    if args.command == "status":
        cli.show_network_status()
    elif args.command == "ap-status":
        cli.show_ap_status(args.ap_id)
    elif args.command == "simulate":
        cli.simulate_incident(args.ap, args.zone, args.issue)
    elif args.command == "replay":
        cli.replay_incident(args.incident_id)
    elif args.command == "resolve":
        cli.resolve_incident(args.incident_id)
    elif args.command == "monitor":
        cli.monitor_network(args.duration)
    elif args.command == "demo":
        cli.demo_scenario()
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
