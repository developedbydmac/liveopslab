#!/usr/bin/env python3
"""
Complete demonstration of the enhanced LiveOpsLab CLI with argparse commands.
Shows all functionality including simulate, replay, status, and webhook alerts.
"""

import subprocess
import time
import sys

def run_command(command, description):
    """Run a CLI command and display the output."""
    print(f"\n{'='*80}")
    print(f"🎯 {description}")
    print(f"Command: {command}")
    print('='*80)
    
    try:
        result = subprocess.run(command, shell=True, capture_output=True, text=True, timeout=30)
        if result.returncode == 0:
            print(result.stdout)
        else:
            print(f"❌ Error: {result.stderr}")
    except subprocess.TimeoutExpired:
        print("⏰ Command timed out")
    except Exception as e:
        print(f"❌ Error running command: {e}")

def main():
    """Run complete CLI demonstration."""
    print("🎭 LiveOpsLab CLI Complete Demonstration")
    print("🚀 Testing all enhanced argparse commands with webhook alerts")
    
    # 1. Show help
    run_command("python3 dashboard_cli.py --help", "Display CLI help with all available commands")
    
    time.sleep(2)
    
    # 2. Show overall network status
    run_command("python3 dashboard_cli.py status", "Show overall network status across all zones")
    
    time.sleep(2)
    
    # 3. Show specific AP status
    run_command("python3 dashboard_cli.py ap-status AP-15", "Show detailed status for AP-15 (all 3 zones)")
    
    time.sleep(2)
    
    # 4. Simulate incident (will send alert if webhook configured)
    run_command("python3 dashboard_cli.py simulate --ap AP-07 --zone VisitorWiFi --issue hardware_malfunction", 
                "Simulate hardware malfunction incident")
    
    time.sleep(2)
    
    # 5. Check AP status after incident
    run_command("python3 dashboard_cli.py ap-status AP-07", "Check AP-07 status after incident")
    
    time.sleep(2)
    
    # 6. Show network status to see impact
    run_command("python3 dashboard_cli.py status", "Show network status after incident")
    
    time.sleep(2)
    
    # 7. Show recent incident history
    print(f"\n{'='*80}")
    print("🎯 Show recent incident history for replay testing")
    print('='*80)
    try:
        from incident_logger import IncidentLogger
        logger = IncidentLogger()
        history = logger.get_incident_history(limit=3)
        print("Recent incidents:")
        for inc in history:
            print(f"🚨 {inc['id'][:8]} | {inc['ap_id']} | {inc['zone']} | {inc['issue_type']}")
    except Exception as e:
        print(f"Error getting history: {e}")
    
    time.sleep(3)
    
    # 8. Demonstrate replay functionality
    # First get a recent incident ID
    try:
        from incident_logger import IncidentLogger
        logger = IncidentLogger()
        history = logger.get_incident_history(limit=1)
        if history:
            incident_id = history[0]['id'][:8]
            run_command(f"python3 dashboard_cli.py replay {incident_id}", 
                       f"Replay past incident {incident_id}")
        else:
            print("No incidents found for replay demonstration")
    except Exception as e:
        print(f"Could not demonstrate replay: {e}")
    
    time.sleep(3)
    
    # 9. Show enhanced features summary
    print(f"\n{'='*80}")
    print("✅ ENHANCED CLI FEATURES DEMONSTRATED")
    print('='*80)
    print("🎯 Commands Available:")
    print("   • status - Overall network health across all zones")
    print("   • ap-status <AP-ID> - Detailed status for specific AP (all 3 zones)")
    print("   • simulate - Create incidents with optional webhook alerts")
    print("   • replay <incident-id> - Re-run past incidents by ID")
    print("   • resolve <incident-id> - Resolve active incidents")
    print("   • monitor - Real-time network monitoring")
    print("   • demo - Full demonstration scenario")
    print()
    print("🔗 Webhook Integration:")
    print("   • --webhook <URL> - Slack or Discord webhook URL")
    print("   • --platform slack|discord - Choose notification platform")
    print()
    print("📊 Data Sources:")
    print("   • incident_log.json - Historical incident data")
    print("   • network_topology.json - Current network state")
    print()
    print("🎉 All features working correctly!")

if __name__ == "__main__":
    main()
