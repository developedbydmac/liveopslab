#!/bin/bash
# VisitorWiFi Instance Initialization Script
# This script sets up the instance for staff and visitor access

# Update system
yum update -y

# Install required packages
yum install -y nginx htop wget curl net-tools iptables-services nodejs npm

# Set hostname
hostnamectl set-hostname ${hostname}

# Configure nginx for staff portal
cat > /etc/nginx/conf.d/visitorwifi.conf << 'EOF'
server {
    listen 80 default_server;
    server_name _;
    
    location / {
        root /var/www/visitorwifi;
        index index.html;
        try_files $uri $uri/ /index.html;
    }
    
    # Staff application proxy
    location /staff-app/ {
        proxy_pass http://127.0.0.1:8080/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF

# Create web directory and staff portal
mkdir -p /var/www/visitorwifi
cat > /var/www/visitorwifi/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LiveOpsLab - Staff WiFi</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; background: #e8f4f8; }
        .container { background: white; padding: 30px; border-radius: 10px; max-width: 600px; margin: 0 auto; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        .logo { font-size: 24px; color: #007cba; margin-bottom: 20px; }
        .features { text-align: left; margin: 20px 0; }
        .feature { margin: 10px 0; padding: 10px; background: #f9f9f9; border-radius: 5px; }
        button { background: #28a745; color: white; padding: 15px 30px; border: none; border-radius: 5px; font-size: 16px; cursor: pointer; margin: 5px; }
        button:hover { background: #218838; }
        .staff-button { background: #007cba; }
        .staff-button:hover { background: #005a87; }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">🎵 LiveOpsLab Staff Portal</div>
        <h2>Welcome Staff & VIP Visitors!</h2>
        <p>Enhanced network access for venue operations.</p>
        
        <div class="features">
            <div class="feature">
                <strong>Network:</strong> VisitorWiFi<br>
                <strong>Speed:</strong> Up to 50 Mbps per device
            </div>
            <div class="feature">
                <strong>Features:</strong> Priority access, extended time limits, internal tools access
            </div>
            <div class="feature">
                <strong>Access:</strong> Staff applications, management tools, monitoring dashboards
            </div>
        </div>
        
        <button onclick="window.location.href='http://example.com'">Connect to Internet</button>
        <button class="staff-button" onclick="window.location.href='/staff-app/'">Staff Applications</button>
        
        <hr>
        <small>For technical support, contact the backstage team.</small>
    </div>
</body>
</html>
EOF

# Create a simple staff application
mkdir -p /opt/staff-app
cat > /opt/staff-app/server.js << 'EOF'
const http = require('http');
const url = require('url');
const fs = require('fs');
const path = require('path');

const server = http.createServer((req, res) => {
    const parsedUrl = url.parse(req.url, true);
    const pathname = parsedUrl.pathname;
    
    res.setHeader('Content-Type', 'text/html');
    
    if (pathname === '/') {
        res.writeHead(200);
        res.end(`
            <!DOCTYPE html>
            <html>
            <head>
                <title>Staff Dashboard</title>
                <style>
                    body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
                    .dashboard { background: white; padding: 30px; border-radius: 10px; }
                    .metric { display: inline-block; margin: 15px; padding: 20px; background: #007cba; color: white; border-radius: 5px; min-width: 150px; }
                    h1 { color: #333; }
                </style>
            </head>
            <body>
                <div class="dashboard">
                    <h1>🎵 LiveOpsLab Staff Dashboard</h1>
                    <p>Real-time venue operations monitoring</p>
                    
                    <div class="metric">
                        <h3>Fan WiFi Users</h3>
                        <div id="fanUsers">245</div>
                    </div>
                    
                    <div class="metric">
                        <h3>Staff Connected</h3>
                        <div id="staffUsers">18</div>
                    </div>
                    
                    <div class="metric">
                        <h3>Network Load</h3>
                        <div id="networkLoad">67%</div>
                    </div>
                    
                    <div class="metric">
                        <h3>System Status</h3>
                        <div id="systemStatus">✅ Operational</div>
                    </div>
                    
                    <h2>Quick Actions</h2>
                    <button onclick="alert('Feature coming soon!')">Restart Services</button>
                    <button onclick="alert('Feature coming soon!')">View Logs</button>
                    <button onclick="alert('Feature coming soon!')">Network Stats</button>
                </div>
                
                <script>
                    // Simulate real-time updates
                    setInterval(() => {
                        document.getElementById('fanUsers').textContent = Math.floor(Math.random() * 50) + 200;
                        document.getElementById('networkLoad').textContent = Math.floor(Math.random() * 40) + 50 + '%';
                    }, 5000);
                </script>
            </body>
            </html>
        `);
    } else {
        res.writeHead(404);
        res.end('Not Found');
    }
});

server.listen(8080, '127.0.0.1', () => {
    console.log('Staff application running on port 8080');
});
EOF

# Configure firewall for staff access
systemctl enable iptables
systemctl start iptables

# Allow HTTP and staff application traffic
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -p tcp --dport 8080 -s 10.0.0.0/16 -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -s 10.0.3.0/24 -j ACCEPT
iptables -A INPUT -p icmp -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
service iptables save

# Start services
systemctl start nginx
systemctl enable nginx

# Start staff application
cd /opt/staff-app
npm init -y
node server.js &

# Create systemd service for staff app
cat > /etc/systemd/system/staff-app.service << 'EOF'
[Unit]
Description=Staff Application
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/staff-app
ExecStart=/usr/bin/node server.js
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable staff-app
systemctl start staff-app

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Create log file for monitoring
echo "$(date): VisitorWiFi instance initialized successfully" >> /var/log/venue-setup.log

# Set up CloudWatch monitoring
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
    "metrics": {
        "namespace": "LiveOpsLab/VisitorWiFi",
        "metrics_collected": {
            "cpu": {
                "measurement": ["cpu_usage_idle", "cpu_usage_iowait", "cpu_usage_user", "cpu_usage_system"],
                "metrics_collection_interval": 60
            },
            "disk": {
                "measurement": ["used_percent"],
                "metrics_collection_interval": 60,
                "resources": ["*"]
            },
            "mem": {
                "measurement": ["mem_used_percent"],
                "metrics_collection_interval": 60
            }
        }
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/nginx/access.log",
                        "log_group_name": "/aws/ec2/visitorwifi/nginx/access",
                        "log_stream_name": "{instance_id}"
                    },
                    {
                        "file_path": "/var/log/venue-setup.log",
                        "log_group_name": "/aws/ec2/visitorwifi/setup",
                        "log_stream_name": "{instance_id}"
                    }
                ]
            }
        }
    }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

echo "VisitorWiFi setup completed at $(date)" >> /var/log/venue-setup.log
