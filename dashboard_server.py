#!/usr/bin/env python3
"""
Simple HTTP server for LiveOpsLab Network Dashboard.
Serves the dashboard and provides real-time network topology data.
"""

import json
import os
import time
import threading
from http.server import HTTPServer, SimpleHTTPRequestHandler
from datetime import datetime
from incident_logger import IncidentLogger

class DashboardHandler(SimpleHTTPRequestHandler):
    """Custom HTTP handler for the dashboard."""
    
    def __init__(self, *args, **kwargs):
        # Initialize incident logger for network data
        self.incident_logger = IncidentLogger()
        super().__init__(*args, **kwargs)
    
    def do_GET(self):
        """Handle GET requests."""
        if self.path == '/':
            self.path = '/network_dashboard.html'
        elif self.path == '/network_topology.json':
            self.serve_network_topology()
            return
        elif self.path == '/api/simulate_incident':
            self.serve_incident_simulation()
            return
        
        return super().do_GET()
    
    def serve_network_topology(self):
        """Serve network topology JSON data."""
        try:
            # Generate fresh network data
            network_data = self.generate_network_topology()
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            json_response = json.dumps(network_data, indent=2)
            self.wfile.write(json_response.encode())
            
        except Exception as e:
            self.send_error(500, f"Error generating network data: {str(e)}")
    
    def serve_incident_simulation(self):
        """Serve incident simulation endpoint."""
        try:
            # Simulate a random incident for demonstration
            import random
            
            ap_ids = [f"AP-{i:02d}" for i in range(1, 51)]
            zones = ["FanWiFi", "VisitorWiFi", "Backstage"]
            issue_types = ["network_connectivity", "power_failure", "hardware_malfunction"]
            
            ap_id = random.choice(ap_ids)
            zone = random.choice(zones)
            issue_type = random.choice(issue_types)
            
            # Use incident logger to simulate incident
            result = self.incident_logger.simulate_incident(ap_id, zone, issue_type)
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            self.wfile.write(json.dumps(result, indent=2).encode())
            
        except Exception as e:
            self.send_error(500, f"Error simulating incident: {str(e)}")
    
    def generate_network_topology(self):
        """Generate real-time network topology data."""
        # Check if we have existing network data from incident logger
        if hasattr(self.incident_logger, 'network_data') and self.incident_logger.network_data.get('access_points'):
            return self.incident_logger.network_data
        
        # Generate fresh network topology
        zones = ['FanWiFi', 'VisitorWiFi', 'Backstage']
        access_points = []
        
        for i in range(1, 51):
            ap_id = f"AP-{i:02d}"
            switch_id = f"Switch-{((i-1)//3 + 1):02d}"  # 3 APs per switch
            
            ap = {
                "ap_id": ap_id,
                "switch_id": switch_id,
                "location": {
                    "floor": (i - 1) // 12 + 1,  # 12 APs per floor
                    "section": ["North", "South", "East", "West"][(i - 1) % 4]
                },
                "hardware": {
                    "model": ["Cisco AP-2700", "Aruba AP-325", "Ubiquiti UAP-AC-HD"][i % 3],
                    "uptime_hours": 100 + (i * 47) % 8000,  # Pseudo-random but consistent
                    "firmware": "v2.4.1"
                },
                "zones": {}
            }
            
            # Generate zone data with some variation
            for zone_idx, zone in enumerate(zones):
                # Create some realistic patterns
                base_latency = 15 + (i * 3) % 40  # Base latency varies by AP
                issue_probability = 0.05 + (0.1 if zone == "FanWiFi" else 0)  # Fan WiFi has more issues
                
                # Simulate time-based variations
                time_factor = (int(time.time()) // 30) % 10  # Change every 30 seconds
                has_issue = (i + zone_idx + time_factor) % 20 == 0  # 5% chance, varies over time
                
                if has_issue:
                    latency = base_latency + 50 + (i * 7) % 100
                    status = "warning" if latency < 120 else "down"
                    clients = 0 if status == "down" else max(0, 15 - (i % 20))
                    throughput = 0.0 if status == "down" else round(10 + (i % 30), 1)
                else:
                    latency = base_latency + (time_factor % 3) * 5  # Small variations
                    status = "healthy"
                    clients = 5 + (i + zone_idx * 10) % 25
                    throughput = round(20.5 + (i * 1.7) % 75, 1)
                
                ap["zones"][zone] = {
                    "status": status,
                    "latency_ms": latency,
                    "connected_clients": clients,
                    "throughput_mbps": throughput,
                    "last_updated": datetime.now().isoformat()
                }
            
            access_points.append(ap)
        
        network_data = {
            "access_points": access_points,
            "generated_at": datetime.now().isoformat(),
            "total_aps": len(access_points)
        }
        
        # Save to file for persistence
        with open('network_topology.json', 'w') as f:
            json.dump(network_data, f, indent=2)
        
        return network_data

def start_dashboard_server(port=8080):
    """Start the dashboard HTTP server."""
    
    # Change to the directory containing the HTML file
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    
    server_address = ('', port)
    httpd = HTTPServer(server_address, DashboardHandler)
    
    print(f"🌐 LiveOpsLab Network Dashboard Server")
    print(f"🚀 Server starting on http://localhost:{port}")
    print(f"📊 Dashboard: http://localhost:{port}")
    print(f"🔧 Network API: http://localhost:{port}/network_topology.json")
    print(f"⚠️  Incident API: http://localhost:{port}/api/simulate_incident")
    print("Press Ctrl+C to stop the server")
    print("-" * 60)
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n🛑 Server stopped by user")
        httpd.server_close()

if __name__ == "__main__":
    start_dashboard_server()
