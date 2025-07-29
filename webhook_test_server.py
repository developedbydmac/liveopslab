#!/usr/bin/env python3
"""
Simple webhook test server to demonstrate alert notifications.
"""

import json
from http.server import HTTPServer, BaseHTTPRequestHandler
import threading
import time

class WebhookHandler(BaseHTTPRequestHandler):
    """Handler for webhook POST requests."""
    
    def do_POST(self):
        """Handle incoming webhook POST requests."""
        content_length = int(self.headers.get('Content-Length', 0))
        post_data = self.rfile.read(content_length)
        
        try:
            payload = json.loads(post_data.decode('utf-8'))
            
            print("\n" + "="*60)
            print("🚨 WEBHOOK ALERT RECEIVED")
            print("="*60)
            
            # Handle Slack format
            if 'text' in payload:
                print(f"Platform: Slack")
                print(f"Message: {payload['text']}")
                if 'attachments' in payload:
                    for attachment in payload['attachments']:
                        if 'fields' in attachment:
                            for field in attachment['fields']:
                                print(f"{field['title']}: {field['value']}")
            
            # Handle Discord format
            elif 'embeds' in payload:
                print(f"Platform: Discord")
                for embed in payload['embeds']:
                    print(f"Title: {embed.get('title', 'N/A')}")
                    print(f"Description: {embed.get('description', 'N/A')}")
                    if 'fields' in embed:
                        for field in embed['fields']:
                            print(f"{field['name']}: {field['value']}")
            
            print("="*60)
            
            # Send success response
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(b'{"status": "received"}')
            
        except Exception as e:
            print(f"❌ Error processing webhook: {e}")
            self.send_response(400)
            self.end_headers()
    
    def log_message(self, format, *args):
        """Suppress default logging."""
        pass

def start_webhook_server(port=9999):
    """Start the webhook test server."""
    server_address = ('', port)
    httpd = HTTPServer(server_address, WebhookHandler)
    
    print(f"🔗 Webhook Test Server started on http://localhost:{port}")
    print(f"💡 Use this URL for testing: http://localhost:{port}/webhook")
    print("Press Ctrl+C to stop")
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n🛑 Webhook server stopped")
        httpd.server_close()

if __name__ == "__main__":
    start_webhook_server()
