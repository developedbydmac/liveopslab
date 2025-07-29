#!/usr/bin/env python3
"""
Simple HTTP server specifically for the LiveOpsLab Network Dashboard.
"""

import os
import json
import time
from http.server import HTTPServer, SimpleHTTPRequestHandler
from datetime import datetime

class DashboardHTTPHandler(SimpleHTTPRequestHandler):
    """Custom handler for the dashboard."""
    
    def do_GET(self):
        """Handle GET requests."""
        if self.path == '/' or self.path == '/index.html' or self.path.startswith('/?'):
            # Serve the main dashboard - redirect to HTML file
            try:
                with open('executive_dashboard.html', 'rb') as f:
                    content = f.read()
                
                self.send_response(200)
                self.send_header('Content-type', 'text/html')
                self.send_header('Cache-Control', 'no-cache')
                self.end_headers()
                self.wfile.write(content)
                return
            except FileNotFoundError:
                self.send_error(404, "Dashboard HTML file not found")
                return
        elif self.path == '/comparison' or self.path == '/compare':
            # Serve the platform comparison page
            try:
                with open('platform_comparison.html', 'rb') as f:
                    content = f.read()
                
                self.send_response(200)
                self.send_header('Content-type', 'text/html')
                self.send_header('Cache-Control', 'no-cache')
                self.end_headers()
                self.wfile.write(content)
                return
            except FileNotFoundError:
                self.send_error(404, "Comparison page not found")
                return
        elif self.path == '/basic':
            # Serve the basic dashboard (if we had it)
            try:
                with open('network_dashboard.html', 'rb') as f:
                    content = f.read()
                
                self.send_response(200)
                self.send_header('Content-type', 'text/html')
                self.send_header('Cache-Control', 'no-cache')
                self.end_headers()
                self.wfile.write(content)
                return
            except FileNotFoundError:
                # Redirect to executive dashboard if basic not found
                self.send_response(302)
                self.send_header('Location', '/')
                self.end_headers()
                return
        elif self.path == '/network_topology.json':
            # Serve network data
            self.serve_network_data()
            return
        
        return super().do_GET()
    
    def serve_network_data(self):
        """Serve network topology JSON data."""
        try:
            # Check if file exists, otherwise generate mock data
            if os.path.exists('network_topology.json'):
                with open('network_topology.json', 'r') as f:
                    data = json.load(f)
            else:
                # Generate simple mock data
                data = self.generate_mock_data()
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            self.wfile.write(json.dumps(data, indent=2).encode())
            
        except Exception as e:
            self.send_error(500, f"Error serving network data: {str(e)}")
    
    def generate_mock_data(self):
        """Generate simple mock network data."""
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
                    "model": ["Cisco AP-2700", "Aruba AP-325", "Ubiquiti UAP-AC-HD"][i % 3],
                    "uptime_hours": 100 + (i * 47) % 8000
                },
                "zones": {}
            }
            
            # Generate zone data
            zones = ['FanWiFi', 'VisitorWiFi', 'Backstage']
            for zone in zones:
                # Simulate some issues
                has_issue = (i + hash(zone)) % 20 == 0  # 5% chance
                
                if has_issue:
                    latency = 50 + (i * 7) % 100
                    status = "warning" if latency < 120 else "down"
                    clients = 0 if status == "down" else max(0, 15 - (i % 20))
                    throughput = 0.0 if status == "down" else round(10 + (i % 30), 1)
                else:
                    latency = 15 + (i % 3) * 5
                    status = "healthy"
                    clients = 5 + (i * 2) % 25
                    throughput = round(20.5 + (i * 1.7) % 75, 1)
                
                ap["zones"][zone] = {
                    "status": status,
                    "latency_ms": latency,
                    "connected_clients": clients,
                    "throughput_mbps": throughput,
                    "last_updated": datetime.now().isoformat()
                }
            
            access_points.append(ap)
        
        return {
            "access_points": access_points,
            "generated_at": datetime.now().isoformat(),
            "total_aps": len(access_points)
        }

def start_simple_dashboard(port=8889):
    """Start the simple dashboard server."""
    
    # Change to the directory containing the HTML file
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    
    server_address = ('', port)
    httpd = HTTPServer(server_address, DashboardHTTPHandler)
    
    print(f"🌐 LiveOpsLab Dashboard Server (Simple)")
    print(f"🚀 Server starting on http://localhost:{port}")
    print(f"📊 Dashboard: http://localhost:{port}")
    print(f"🔧 Network API: http://localhost:{port}/network_topology.json")
    print("Press Ctrl+C to stop the server")
    print("-" * 60)
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n🛑 Server stopped by user")
        httpd.server_close()

if __name__ == "__main__":
    start_simple_dashboard()
