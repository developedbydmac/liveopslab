#!/usr/bin/env python3
"""
LiveOpsLab Demo Script
Demonstrates the complete AI-powered incident management system
"""

import asyncio
import json
import requests
import time
from datetime import datetime
from typing import Dict, List

class LiveOpsLabDemo:
    def __init__(self, api_base: str = "http://localhost:8000"):
        self.api_base = api_base
        self.zones = ["FanWiFi", "VisitorWiFi", "Backstage"]
        self.demo_scenarios = []
        
    def print_header(self, text: str):
        print("\n" + "="*60)
        print(f"🏟️  {text}")
        print("="*60)
    
    def print_step(self, step: str):
        print(f"\n🔹 {step}")
        
    def print_success(self, message: str):
        print(f"✅ {message}")
        
    def print_info(self, message: str):
        print(f"ℹ️  {message}")
        
    def check_api_health(self) -> bool:
        """Check if the API is running and healthy"""
        try:
            response = requests.get(f"{self.api_base}/health", timeout=5)
            if response.status_code == 200:
                data = response.json()
                self.print_success(f"API is healthy - monitoring {data['zones_monitored']} zones")
                return True
            else:
                print(f"❌ API health check failed: HTTP {response.status_code}")
                return False
        except requests.exceptions.RequestException as e:
            print(f"❌ Cannot connect to API: {e}")
            return False
    
    def show_initial_status(self):
        """Display the initial status of all zones"""
        self.print_step("Checking initial zone status...")
        
        try:
            response = requests.get(f"{self.api_base}/status")
            if response.status_code == 200:
                data = response.json()
                zones = data.get('zones', {})
                
                print("\n📊 Current Zone Status:")
                for zone_name, zone_data in zones.items():
                    status = zone_data.get('status', 'unknown')
                    users = zone_data.get('active_users', 0)
                    latency = zone_data.get('avg_latency_ms', 0)
                    uptime = zone_data.get('uptime_percentage', 0)
                    
                    status_emoji = {
                        'healthy': '🟢',
                        'degraded': '🟡', 
                        'outage': '🔴',
                        'maintenance': '🟣'
                    }.get(status, '❓')
                    
                    print(f"   {status_emoji} {zone_name}: {status.upper()} | "
                          f"{users} users | {latency:.1f}ms | {uptime:.2f}% uptime")
                
                self.print_success("All zones are operational!")
            else:
                print(f"❌ Failed to get zone status: HTTP {response.status_code}")
        except Exception as e:
            print(f"❌ Error getting zone status: {e}")
    
    def simulate_network_failure(self):
        """Demonstrate network failure simulation and AI analysis"""
        self.print_step("Simulating network failure in FanWiFi zone...")
        
        try:
            payload = {
                "outage_type": "network_failure",
                "duration_seconds": 90,
                "severity": "high",
                "description": "Demo: Simulated network interface failure during peak usage"
            }
            
            response = requests.post(
                f"{self.api_base}/simulate-outage/FanWiFi",
                json=payload,
                timeout=10
            )
            
            if response.status_code == 200:
                data = response.json()
                incident_id = data.get('incident_id')
                self.print_success(f"Network failure simulated (Incident ID: {incident_id[:8]}...)")
                self.print_info(f"Estimated duration: {payload['duration_seconds']} seconds")
                
                # Wait and show zone status change
                time.sleep(3)
                self.show_incident_impact("FanWiFi")
                
                return incident_id
            else:
                print(f"❌ Failed to simulate outage: HTTP {response.status_code}")
                return None
                
        except Exception as e:
            print(f"❌ Error simulating outage: {e}")
            return None
    
    def simulate_high_latency(self):
        """Demonstrate high latency simulation"""
        self.print_step("Simulating high latency in VisitorWiFi zone...")
        
        try:
            payload = {
                "outage_type": "high_latency",
                "duration_seconds": 60,
                "severity": "medium",
                "description": "Demo: Network congestion causing increased response times"
            }
            
            response = requests.post(
                f"{self.api_base}/simulate-outage/VisitorWiFi",
                json=payload,
                timeout=10
            )
            
            if response.status_code == 200:
                data = response.json()
                incident_id = data.get('incident_id')
                self.print_success(f"High latency simulated (Incident ID: {incident_id[:8]}...)")
                
                time.sleep(2)
                self.show_incident_impact("VisitorWiFi")
                
                return incident_id
            else:
                print(f"❌ Failed to simulate latency: HTTP {response.status_code}")
                return None
                
        except Exception as e:
            print(f"❌ Error simulating latency: {e}")
            return None
    
    def show_incident_impact(self, zone: str):
        """Show the impact of an incident on a specific zone"""
        try:
            response = requests.get(f"{self.api_base}/status/{zone}")
            if response.status_code == 200:
                data = response.json()
                status = data.get('status', 'unknown')
                latency = data.get('avg_latency_ms', 0)
                incidents = data.get('current_incidents', [])
                
                status_emoji = {
                    'healthy': '🟢',
                    'degraded': '🟡',
                    'outage': '🔴',
                    'maintenance': '🟣'
                }.get(status, '❓')
                
                print(f"   📊 {zone} Status: {status_emoji} {status.upper()}")
                print(f"   📈 Current Latency: {latency:.1f}ms")
                if incidents:
                    print(f"   🚨 Active Incidents: {len(incidents)}")
                    
        except Exception as e:
            print(f"⚠️  Could not get zone status: {e}")
    
    def wait_for_ai_analysis(self, incident_id: str, max_wait: int = 30):
        """Wait for AI analysis to complete"""
        self.print_step("Waiting for AI analysis...")
        
        for i in range(max_wait):
            try:
                response = requests.get(f"{self.api_base}/replay/{incident_id}")
                if response.status_code == 200:
                    data = response.json()
                    ai_analysis = data.get('ai_analysis', {})
                    
                    if ai_analysis and ai_analysis.get('root_cause'):
                        self.print_success("AI analysis completed!")
                        self.display_ai_analysis(ai_analysis)
                        return ai_analysis
                    
                if i < max_wait - 1:
                    print(f"   ⏳ Analysis in progress... ({i+1}/{max_wait})")
                    time.sleep(1)
                    
            except Exception as e:
                print(f"⚠️  Error checking analysis: {e}")
                break
        
        self.print_info("AI analysis is still processing - check /replay endpoint later")
        return None
    
    def display_ai_analysis(self, analysis: Dict):
        """Display AI analysis results"""
        print("\n🧠 AI Analysis Results:")
        print("-" * 40)
        
        root_cause = analysis.get('root_cause', 'Unknown')
        confidence = analysis.get('confidence_level', 0) * 100
        recommended_fix = analysis.get('recommended_fix', 'No recommendation')
        escalation = analysis.get('escalation_needed', False)
        recovery_time = analysis.get('estimated_recovery_time', 'Unknown')
        
        print(f"🎯 Root Cause: {root_cause}")
        print(f"📊 Confidence: {confidence:.1f}%")
        print(f"🔧 Recommended Fix: {recommended_fix}")
        print(f"⏱️  Recovery Time: {recovery_time}")
        print(f"🚨 Escalation Needed: {'Yes' if escalation else 'No'}")
        
        preventive_measures = analysis.get('preventive_measures', [])
        if preventive_measures:
            print(f"\n💡 Preventive Measures:")
            for measure in preventive_measures[:3]:  # Show top 3
                print(f"   • {measure}")
    
    def show_incident_timeline(self, incident_id: str):
        """Show incident timeline and lessons learned"""
        try:
            response = requests.get(f"{self.api_base}/replay/{incident_id}")
            if response.status_code == 200:
                data = response.json()
                timeline = data.get('timeline', [])
                lessons = data.get('lessons_learned', [])
                
                if timeline:
                    print(f"\n📅 Incident Timeline (ID: {incident_id[:8]}...):")
                    print("-" * 50)
                    for event in timeline:
                        timestamp = event.get('timestamp', '')
                        event_type = event.get('event', '')
                        details = event.get('details', '')
                        
                        # Format timestamp for display
                        try:
                            dt = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
                            time_str = dt.strftime('%H:%M:%S')
                        except:
                            time_str = timestamp[:8] if timestamp else 'Unknown'
                        
                        print(f"   {time_str} | {event_type}: {details}")
                
                if lessons:
                    print(f"\n📚 Lessons Learned:")
                    for lesson in lessons[:3]:  # Show top 3
                        print(f"   💡 {lesson}")
                        
        except Exception as e:
            print(f"⚠️  Could not get incident timeline: {e}")
    
    def wait_for_recovery(self, zone: str, max_wait: int = 100):
        """Wait for zone to recover to healthy status"""
        self.print_step(f"Waiting for {zone} to recover...")
        
        for i in range(max_wait):
            try:
                response = requests.get(f"{self.api_base}/status/{zone}")
                if response.status_code == 200:
                    data = response.json()
                    status = data.get('status', 'unknown')
                    
                    if status == 'healthy':
                        self.print_success(f"{zone} has recovered to healthy status!")
                        return True
                    
                    if i % 10 == 0:  # Show progress every 10 seconds
                        print(f"   ⏳ Recovery in progress... Status: {status.upper()} ({i+1}s)")
                        
                time.sleep(1)
                
            except Exception as e:
                print(f"⚠️  Error checking recovery: {e}")
                break
        
        print(f"⚠️  {zone} recovery is taking longer than expected")
        return False
    
    def show_final_status(self):
        """Show final status of all zones"""
        self.print_step("Final system status check...")
        
        try:
            response = requests.get(f"{self.api_base}/status")
            if response.status_code == 200:
                data = response.json()
                zones = data.get('zones', {})
                
                print("\n📊 Final Zone Status:")
                healthy_zones = 0
                
                for zone_name, zone_data in zones.items():
                    status = zone_data.get('status', 'unknown')
                    users = zone_data.get('active_users', 0)
                    uptime = zone_data.get('uptime_percentage', 0)
                    
                    status_emoji = {
                        'healthy': '🟢',
                        'degraded': '🟡',
                        'outage': '🔴',
                        'maintenance': '🟣'
                    }.get(status, '❓')
                    
                    if status == 'healthy':
                        healthy_zones += 1
                    
                    print(f"   {status_emoji} {zone_name}: {status.upper()} | "
                          f"{users} users | {uptime:.2f}% uptime")
                
                if healthy_zones == len(zones):
                    self.print_success("All zones have recovered successfully! 🎉")
                else:
                    print(f"⚠️  {healthy_zones}/{len(zones)} zones are healthy")
                    
        except Exception as e:
            print(f"❌ Error getting final status: {e}")
    
    def show_recent_incidents(self):
        """Show summary of recent incidents"""
        self.print_step("Recent incident summary...")
        
        try:
            response = requests.get(f"{self.api_base}/incidents?limit=5")
            if response.status_code == 200:
                data = response.json()
                incidents = data.get('incidents', [])
                
                if incidents:
                    print(f"\n📋 Recent Incidents ({len(incidents)}):")
                    print("-" * 50)
                    
                    for incident in incidents:
                        incident_id = incident.get('id', 'Unknown')[:8]
                        zone = incident.get('zone', 'Unknown')
                        outage_type = incident.get('outage_type', 'unknown')
                        severity = incident.get('severity', 'unknown')
                        status = incident.get('status', 'unknown')
                        duration = incident.get('duration_seconds', 0)
                        
                        status_emoji = {
                            'active': '🔴',
                            'resolved': '✅',
                            'investigating': '🔍'
                        }.get(status, '❓')
                        
                        print(f"   {status_emoji} {incident_id}... | {zone} | {outage_type} | "
                              f"{severity} | {duration}s | {status}")
                else:
                    print("   No recent incidents found")
                    
        except Exception as e:
            print(f"⚠️  Could not get incident history: {e}")
    
    async def run_demo(self):
        """Run the complete LiveOpsLab demonstration"""
        self.print_header("LiveOpsLab AI-Powered Incident Management Demo")
        
        # Step 1: Health check
        if not self.check_api_health():
            print("\n❌ Demo cannot continue - API is not accessible")
            print("💡 Make sure to run: uvicorn main:app --host 0.0.0.0 --port 8000")
            return
        
        # Step 2: Show initial status
        self.show_initial_status()
        
        input("\n🎬 Press Enter to start the incident simulation demo...")
        
        # Step 3: Simulate network failure
        self.print_header("Network Failure Simulation & AI Analysis")
        incident_1 = self.simulate_network_failure()
        
        if incident_1:
            # Wait for AI analysis
            ai_analysis = self.wait_for_ai_analysis(incident_1)
            
            input("\n🎬 Press Enter to continue to the next simulation...")
            
            # Step 4: Simulate high latency
            self.print_header("High Latency Simulation")
            incident_2 = self.simulate_high_latency()
            
            # Step 5: Show recovery process
            self.print_header("Automated Recovery Process")
            self.wait_for_recovery("FanWiFi", 95)
            if incident_2:
                self.wait_for_recovery("VisitorWiFi", 65)
            
            # Step 6: Show incident timeline
            self.print_header("Incident Analysis & Lessons Learned")
            if incident_1:
                self.show_incident_timeline(incident_1)
            
            # Step 7: Final status
            self.print_header("System Recovery Validation")
            self.show_final_status()
            self.show_recent_incidents()
            
            # Step 8: Demo conclusion
            self.print_header("Demo Summary")
            print("🎯 What we demonstrated:")
            print("   ✅ Real-time incident simulation")
            print("   ✅ AI-powered root cause analysis") 
            print("   ✅ Automated recovery processes")
            print("   ✅ Comprehensive monitoring and alerting")
            print("   ✅ Incident timeline and lessons learned")
            print("   ✅ Multi-zone network management")
            
            print("\n🌐 Access Points:")
            print("   • Dashboard: http://localhost:3000")
            print("   • API Docs:  http://localhost:8000/docs")
            print("   • Health:    http://localhost:8000/health")
            
            print("\n🚀 Next Steps:")
            print("   • Explore the interactive dashboard")
            print("   • Try manual incident simulations")
            print("   • Review AI analysis accuracy")
            print("   • Implement custom chaos scenarios")
            
            self.print_success("LiveOpsLab demo completed successfully! 🏟️")
        
        else:
            print("❌ Demo could not continue due to simulation failures")

def main():
    demo = LiveOpsLabDemo()
    
    try:
        asyncio.run(demo.run_demo())
    except KeyboardInterrupt:
        print("\n\n🛑 Demo interrupted by user")
    except Exception as e:
        print(f"\n❌ Demo failed with error: {e}")

if __name__ == "__main__":
    main()
