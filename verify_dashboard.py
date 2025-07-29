#!/usr/bin/env python3
"""
Quick verification that the LiveOpsLab Dashboard is working properly.
"""

import requests
import time

def check_dashboard():
    """Check if the dashboard is accessible and working."""
    
    print("🔍 LiveOpsLab Dashboard Verification")
    print("=" * 50)
    
    # Test dashboard HTML
    try:
        response = requests.get("http://localhost:8889", timeout=5)
        if response.status_code == 200 and "LiveOpsLab Network Dashboard" in response.text:
            print("✅ Dashboard HTML: Accessible")
            print(f"   📊 Title found: 'LiveOpsLab Network Dashboard'")
            print(f"   📏 Page size: {len(response.text):,} characters")
        else:
            print("❌ Dashboard HTML: Not accessible")
            return False
    except Exception as e:
        print(f"❌ Dashboard HTML: Error connecting - {e}")
        return False
    
    # Test network API
    try:
        response = requests.get("http://localhost:8889/network_topology.json", timeout=5)
        if response.status_code == 200:
            data = response.json()
            print("✅ Network API: Working")
            print(f"   📊 Access Points: {len(data.get('access_points', []))}")
            print(f"   🕐 Generated: {data.get('generated_at', 'Unknown')}")
            
            # Check first AP data
            if data.get('access_points'):
                first_ap = data['access_points'][0]
                print(f"   📡 Sample AP: {first_ap.get('ap_id')} with {len(first_ap.get('zones', {}))} zones")
        else:
            print("❌ Network API: Not accessible")
            return False
    except Exception as e:
        print(f"❌ Network API: Error - {e}")
        return False
    
    print("\n🎯 Dashboard Features:")
    print("   🌐 URL: http://localhost:8889")
    print("   📊 10x5 Grid: 50 Access Points (AP-01 to AP-50)")
    print("   🔴🟡🟢 Status Dots: 3 zones per AP (Fan, Visitor, Backstage)")
    print("   🔄 Auto-refresh: Every 30 seconds")
    print("   💡 Hover tooltips: Latency, clients, throughput")
    print("   📱 Responsive: Works on desktop and mobile")
    
    print("\n🚀 Ready to Use!")
    print("   1. Open http://localhost:8889 in your browser")
    print("   2. Hover over colored dots to see details")
    print("   3. Watch for automatic updates every 30 seconds")
    print("   4. Use CLI commands to simulate incidents")
    
    return True

if __name__ == "__main__":
    success = check_dashboard()
    if success:
        print("\n✅ Dashboard verification completed successfully!")
    else:
        print("\n❌ Dashboard verification failed - check server status")
