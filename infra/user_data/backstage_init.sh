#!/bin/bash
# Backstage Instance Initialization Script
# This script sets up the management and monitoring instance

# Update system
yum update -y

# Install required packages
yum install -y nginx htop wget curl net-tools iptables-services docker python3 python3-pip git

# Set hostname
hostnamectl set-hostname ${hostname}

# Start and enable Docker
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Configure nginx for management portal
cat > /etc/nginx/conf.d/backstage.conf << 'EOF'
server {
    listen 80 default_server;
    server_name _;
    
    location / {
        root /var/www/backstage;
        index index.html;
        try_files $uri $uri/ /index.html;
    }
    
    # Prometheus proxy
    location /prometheus/ {
        proxy_pass http://127.0.0.1:9090/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Grafana proxy
    location /grafana/ {
        proxy_pass http://127.0.0.1:3000/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Create management portal
mkdir -p /var/www/backstage
cat > /var/www/backstage/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LiveOpsLab - Backstage Management</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background: #1a1a1a; color: white; }
        .container { max-width: 1200px; margin: 0 auto; }
        .header { text-align: center; margin-bottom: 40px; }
        .logo { font-size: 28px; color: #ff6b6b; margin-bottom: 10px; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
        .card { background: #2d2d2d; padding: 25px; border-radius: 10px; border-left: 4px solid #ff6b6b; }
        .card h3 { color: #ff6b6b; margin-top: 0; }
        .button { display: inline-block; background: #ff6b6b; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; margin: 5px; transition: background 0.3s; }
        .button:hover { background: #ff5252; }
        .status { padding: 10px; border-radius: 5px; margin: 10px 0; }
        .status.good { background: #4caf50; }
        .status.warning { background: #ff9800; }
        .metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 15px; margin: 20px 0; }
        .metric { background: #3d3d3d; padding: 15px; border-radius: 8px; text-align: center; }
        .metric-value { font-size: 24px; font-weight: bold; color: #4caf50; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">🎵 LiveOpsLab Backstage</div>
            <h1>Venue Management Console</h1>
            <p>Centralized control and monitoring for venue operations</p>
        </div>
        
        <div class="metrics">
            <div class="metric">
                <div class="metric-value" id="totalUsers">263</div>
                <div>Total Users</div>
            </div>
            <div class="metric">
                <div class="metric-value" id="networkUptime">99.8%</div>
                <div>Network Uptime</div>
            </div>
            <div class="metric">
                <div class="metric-value" id="avgLoad">34%</div>
                <div>Avg Load</div>
            </div>
            <div class="metric">
                <div class="metric-value" id="activeAlerts">0</div>
                <div>Active Alerts</div>
            </div>
        </div>
        
        <div class="grid">
            <div class="card">
                <h3>🌐 Network Status</h3>
                <div class="status good">✅ All Networks Operational</div>
                <ul>
                    <li><strong>FanWiFi:</strong> 245 users connected</li>
                    <li><strong>VisitorWiFi:</strong> 18 staff connected</li>
                    <li><strong>Backstage:</strong> 3 management users</li>
                </ul>
                <a href="#" class="button">View Network Details</a>
            </div>
            
            <div class="card">
                <h3>📊 Monitoring Tools</h3>
                <p>Access real-time metrics and system monitoring dashboards.</p>
                <a href="/prometheus/" class="button">Prometheus Metrics</a>
                <a href="/grafana/" class="button">Grafana Dashboard</a>
                <a href="#" class="button">System Logs</a>
            </div>
            
            <div class="card">
                <h3>⚙️ System Management</h3>
                <p>Control venue infrastructure and services.</p>
                <a href="#" class="button">Service Control</a>
                <a href="#" class="button">User Management</a>
                <a href="#" class="button">Security Settings</a>
            </div>
            
            <div class="card">
                <h3>🚨 Alerts & Events</h3>
                <div class="status good">✅ No Active Alerts</div>
                <p>Last event: Network optimization completed at 14:32</p>
                <a href="#" class="button">View All Events</a>
                <a href="#" class="button">Configure Alerts</a>
            </div>
            
            <div class="card">
                <h3>📈 Performance Analytics</h3>
                <p>Venue network usage and performance insights.</p>
                <ul>
                    <li>Peak usage: 14:00-16:00</li>
                    <li>Average bandwidth: 45 Mbps</li>
                    <li>Connection success rate: 98.7%</li>
                </ul>
                <a href="#" class="button">Detailed Analytics</a>
            </div>
            
            <div class="card">
                <h3>🔒 Security Center</h3>
                <div class="status warning">⚠️ 2 Security Notices</div>
                <p>Monitor network security and access controls.</p>
                <a href="#" class="button">Security Dashboard</a>
                <a href="#" class="button">Access Logs</a>
            </div>
        </div>
    </div>
    
    <script>
        // Simulate real-time updates
        setInterval(() => {
            document.getElementById('totalUsers').textContent = Math.floor(Math.random() * 50) + 250;
            document.getElementById('avgLoad').textContent = Math.floor(Math.random() * 30) + 25 + '%';
        }, 10000);
    </script>
</body>
</html>
EOF

# Create monitoring stack with Docker Compose
mkdir -p /opt/monitoring
cat > /opt/monitoring/docker-compose.yml << 'EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=30d'
      - '--web.enable-lifecycle'
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=liveopslab123
      - GF_SERVER_ROOT_URL=http://localhost:3000/grafana/
      - GF_SERVER_SERVE_FROM_SUB_PATH=true
    volumes:
      - grafana-data:/var/lib/grafana
    depends_on:
      - prometheus
    restart: unless-stopped

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    restart: unless-stopped

volumes:
  prometheus-data:
  grafana-data:
EOF

# Create Prometheus configuration
cat > /opt/monitoring/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['localhost:9100']

  - job_name: 'backstage-server'
    static_configs:
      - targets: ['localhost:9100']
    scrape_interval: 30s
EOF

# Configure firewall for management access
systemctl enable iptables
systemctl start iptables

# Allow management ports
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport 3389 -j ACCEPT
iptables -A INPUT -p tcp --dport 9090 -s 10.0.0.0/16 -j ACCEPT
iptables -A INPUT -p tcp --dport 3000 -s 10.0.0.0/16 -j ACCEPT
iptables -A INPUT -p tcp --dport 9100 -s 10.0.0.0/16 -j ACCEPT
iptables -A INPUT -p icmp -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
service iptables save

# Start services
systemctl start nginx
systemctl enable nginx

# Start monitoring stack
cd /opt/monitoring
/usr/local/bin/docker-compose up -d

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Create log file for monitoring
echo "$(date): Backstage management instance initialized successfully" >> /var/log/venue-setup.log

# Set up advanced CloudWatch monitoring
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
    "metrics": {
        "namespace": "LiveOpsLab/Backstage",
        "metrics_collected": {
            "cpu": {
                "measurement": ["cpu_usage_idle", "cpu_usage_iowait", "cpu_usage_user", "cpu_usage_system"],
                "metrics_collection_interval": 30
            },
            "disk": {
                "measurement": ["used_percent"],
                "metrics_collection_interval": 60,
                "resources": ["*"]
            },
            "mem": {
                "measurement": ["mem_used_percent"],
                "metrics_collection_interval": 30
            },
            "netstat": {
                "measurement": ["tcp_established", "tcp_time_wait"],
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
                        "log_group_name": "/aws/ec2/backstage/nginx/access",
                        "log_stream_name": "{instance_id}"
                    },
                    {
                        "file_path": "/var/log/venue-setup.log",
                        "log_group_name": "/aws/ec2/backstage/setup",
                        "log_stream_name": "{instance_id}"
                    },
                    {
                        "file_path": "/var/log/docker",
                        "log_group_name": "/aws/ec2/backstage/docker",
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

# Create management scripts
mkdir -p /opt/scripts
cat > /opt/scripts/venue-status.sh << 'EOF'
#!/bin/bash
# Venue status check script

echo "=== LiveOpsLab Venue Status ==="
echo "Date: $(date)"
echo ""

echo "=== Network Interfaces ==="
ip addr show | grep -E "inet.*eth0|inet.*ens"

echo ""
echo "=== Docker Services ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "=== System Resources ==="
echo "CPU Usage:"
top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1"%"}'
echo "Memory Usage:"
free -h | grep "Mem:"
echo "Disk Usage:"
df -h / | tail -1

echo ""
echo "=== Service Status ==="
systemctl is-active nginx || echo "nginx: inactive"
systemctl is-active docker || echo "docker: inactive"

echo ""
echo "=== Network Connectivity Test ==="
ping -c 1 8.8.8.8 > /dev/null && echo "Internet: OK" || echo "Internet: FAILED"
EOF

chmod +x /opt/scripts/venue-status.sh

# Add status check to cron
echo "*/5 * * * * /opt/scripts/venue-status.sh >> /var/log/venue-status.log 2>&1" | crontab -

echo "Backstage management setup completed at $(date)" >> /var/log/venue-setup.log
echo "Access the management portal at http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)" >> /var/log/venue-setup.log
