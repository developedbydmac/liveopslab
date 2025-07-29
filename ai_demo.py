#!/usr/bin/env python3
"""
LiveOpsLab AI Analysis Demo
Focused demonstration of AI-powered incident analysis capabilities
"""

import requests
import json
import time
from datetime import datetime

class AIAnalysisDemo:
    def __init__(self, api_base: str = "http://localhost:8000"):
        self.api_base = api_base
        
    def print_header(self, text: str):
        print("\n" + "="*60)
        print(f"🤖 {text}")
        print("="*60)
    
    def print_step(self, step: str):
        print(f"\n🔹 {step}")
        
    def print_success(self, message: str):
        print(f"✅ {message}")
        
    def print_info(self, message: str):
        print(f"ℹ️  {message}")
        
    def simulate_and_analyze_incident(self, zone: str, outage_type: str, severity: str, description: str):
        """Simulate an incident and show detailed AI analysis"""
        
        self.print_step(f"Creating {outage_type} incident in {zone} zone...")
        
        # Simulate the incident
        payload = {
            "outage_type": outage_type,
            "duration_seconds": 45,
            "severity": severity,
            "description": description
        }
        
        try:
            response = requests.post(f"{self.api_base}/simulate-outage/{zone}", 
                                   json=payload, timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                incident_id = data.get('incident_id')
                self.print_success(f"Incident created: {incident_id[:8]}...")
                
                # Wait for AI analysis
                self.print_step("Waiting for AI analysis to complete...")
                time.sleep(3)
                
                # Get detailed incident analysis
                replay_response = requests.get(f"{self.api_base}/replay/{incident_id}")
                
                if replay_response.status_code == 200:
                    analysis_data = replay_response.json()
                    self.display_ai_analysis(analysis_data)
                    return incident_id
                else:
                    print(f"❌ Could not get analysis: HTTP {replay_response.status_code}")
                    return None
                    
            elif response.status_code == 409:
                print(f"⚠️  Zone {zone} already has an active incident")
                # Get existing incidents and show analysis
                incidents_response = requests.get(f"{self.api_base}/incidents")
                if incidents_response.status_code == 200:
                    incidents_data = incidents_response.json()
                    for incident in incidents_data.get('incidents', []):
                        if incident['zone'] == zone and incident['status'] == 'active':
                            replay_response = requests.get(f"{self.api_base}/replay/{incident['id']}")
                            if replay_response.status_code == 200:
                                analysis_data = replay_response.json()
                                self.display_ai_analysis(analysis_data)
                            return incident['id']
                return None
            else:
                print(f"❌ Failed to create incident: HTTP {response.status_code}")
                return None
        except Exception as e:
            print(f"❌ Error: {e}")
            return None
    
    def display_ai_analysis(self, analysis_data):
        """Display comprehensive AI analysis"""
        
        incident = analysis_data.get('incident', {})
        ai_analysis = analysis_data.get('ai_analysis', {})
        timeline = analysis_data.get('timeline', [])
        lessons = analysis_data.get('lessons_learned', [])
        
        print("\n" + "🤖 AI-POWERED INCIDENT ANALYSIS".center(60))
        print("=" * 60)
        
        # Basic incident info
        print(f"📊 Incident ID: {incident.get('id', 'N/A')[:8]}...")
        print(f"📍 Zone: {incident.get('zone', 'N/A')}")
        print(f"⚠️  Type: {incident.get('outage_type', 'N/A')} ({incident.get('severity', 'N/A')})")
        print(f"⏱️  Duration: {incident.get('duration_seconds', 0)}s")
        print(f"👥 Affected Users: {incident.get('affected_users', 0)}")
        print(f"📊 Status: {incident.get('status', 'N/A').upper()}")
        
        # AI Analysis Section
        print("\n🔍 AI ROOT CAUSE ANALYSIS:")
        print(f"  🎯 Root Cause: {ai_analysis.get('root_cause', 'Not available')}")
        print(f"  🔧 Recommended Fix: {ai_analysis.get('recommended_fix', 'Not available')}")
        print(f"  📊 Confidence Level: {ai_analysis.get('confidence_level', 0)*100:.0f}%")
        print(f"  ⚠️  Escalation Needed: {'Yes' if ai_analysis.get('escalation_needed') else 'No'}")
        print(f"  ⏰ Est. Recovery Time: {ai_analysis.get('estimated_recovery_time', 'Unknown')}")
        
        # Preventive Measures
        preventive_measures = ai_analysis.get('preventive_measures', [])
        if preventive_measures:
            print("\n💡 PREVENTIVE MEASURES:")
            for measure in preventive_measures:
                print(f"  • {measure}")
        
        # Timeline
        if timeline:
            print("\n📅 INCIDENT TIMELINE:")
            for event in timeline:
                timestamp = event.get('timestamp', '')[:19].replace('T', ' ')
                print(f"  {timestamp} | {event.get('event', '')}: {event.get('details', '')}")
        
        # Lessons Learned
        if lessons:
            print("\n📚 LESSONS LEARNED:")
            for lesson in lessons:
                print(f"  💡 {lesson}")
        
        # Recent logs
        logs = incident.get('logs', [])
        if logs:
            print("\n📋 INCIDENT LOGS:")
            for log in logs[:3]:  # Show first 3 logs
                print(f"  {log}")
        
        print("=" * 60)
    
    def run_comprehensive_demo(self):
        """Run a comprehensive AI analysis demonstration"""
        
        self.print_header("AI-Powered Incident Management Demo")
        
        # Check API health
        try:
            response = requests.get(f"{self.api_base}/health", timeout=5)
            if response.status_code == 200:
                data = response.json()
                self.print_success(f"API is healthy - monitoring {data['zones_monitored']} zones")
            else:
                print(f"❌ API health check failed: HTTP {response.status_code}")
                return
        except Exception as e:
            print(f"❌ Cannot connect to API: {e}")
            return
        
        # Demo scenarios
        scenarios = [
            {
                "zone": "FanWiFi",
                "outage_type": "network_failure", 
                "severity": "high",
                "description": "AI Demo: Network interface failure simulation"
            },
            {
                "zone": "VisitorWiFi",
                "outage_type": "high_latency",
                "severity": "medium", 
                "description": "AI Demo: Latency spike due to bandwidth congestion"
            },
            {
                "zone": "Backstage",
                "outage_type": "cpu_spike",
                "severity": "medium",
                "description": "AI Demo: CPU overload from monitoring processes"
            }
        ]
        
        incident_ids = []
        
        for i, scenario in enumerate(scenarios, 1):
            self.print_header(f"Scenario {i}/3: {scenario['outage_type'].replace('_', ' ').title()} in {scenario['zone']}")
            
            incident_id = self.simulate_and_analyze_incident(
                scenario['zone'],
                scenario['outage_type'], 
                scenario['severity'],
                scenario['description']
            )
            
            if incident_id:
                incident_ids.append(incident_id)
            
            # Pause between scenarios
            if i < len(scenarios):
                input("\n🎬 Press Enter to continue to next scenario...")
        
        # Show summary
        self.print_header("Demo Summary & Recent Incidents")
        
        try:
            response = requests.get(f"{self.api_base}/incidents?limit=5")
            if response.status_code == 200:
                data = response.json()
                incidents = data.get('incidents', [])
                
                print(f"\n📊 Total Recent Incidents: {len(incidents)}")
                print("━" * 60)
                
                for incident in incidents[:5]:
                    ai = incident.get('ai_analysis', {})
                    status_emoji = {"active": "🔴", "resolved": "✅", "investigating": "🟡"}.get(incident.get('status'), "⚪")
                    
                    print(f"{status_emoji} {incident.get('id', '')[:8]}... | {incident.get('zone')} | {incident.get('outage_type')} | {incident.get('severity')}")
                    print(f"   🤖 AI: {ai.get('root_cause', 'Analysis pending')[:50]}...")
                    print(f"   🔧 Fix: {ai.get('recommended_fix', 'Recommendations pending')[:50]}...")
                    print(f"   📊 Confidence: {ai.get('confidence_level', 0)*100:.0f}%")
                    print()
                
        except Exception as e:
            print(f"❌ Error getting incident summary: {e}")
        
        print("🎉 AI Analysis Demo Complete!")
        print("\n🔗 Additional Access Points:")
        print(f"  • API Documentation: {self.api_base}/docs")
        print(f"  • Health Check: {self.api_base}/health")
        print(f"  • All Incidents: {self.api_base}/incidents")
        print(f"  • Dashboard: http://localhost:3000")

if __name__ == "__main__":
    demo = AIAnalysisDemo()
    demo.run_comprehensive_demo()
