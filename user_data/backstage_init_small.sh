#!/bin/bash
# Backstage Instance Initialization Script - Optimized Version
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

# Create basic nginx configuration
cat > /etc/nginx/conf.d/backstage.conf << 'EOF'
server {
    listen 80 default_server;
    server_name _;
    root /var/www/backstage;
    index index.html;
    
    location /prometheus/ {
        proxy_pass http://127.0.0.1:9090/;
        proxy_set_header Host $host;
    }
    
    location /grafana/ {
        proxy_pass http://127.0.0.1:3000/;
        proxy_set_header Host $host;
    }
}
EOF

# Create simple management portal
mkdir -p /var/www/backstage
cat > /var/www/backstage/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>LiveOpsLab - Backstage Management</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background: #1a1a1a; color: white; }
        .container { max-width: 1200px; margin: 0 auto; }
        .header { text-align: center; margin-bottom: 40px; }
        .logo { font-size: 28px; color: #ff6b6b; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
        .card { background: #2d2d2d; padding: 25px; border-radius: 10px; border-left: 4px solid #ff6b6b; }
        .button { display: inline-block; background: #ff6b6b; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; margin: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">🎵 LiveOpsLab Backstage</div>
            <h1>Venue Management Console</h1>
        </div>
        <div class="grid">
            <div class="card">
                <h3>🌐 Network Status</h3>
                <p>Monitor venue network infrastructure</p>
                <a href="#" class="button">View Network Details</a>
            </div>
            <div class="card">
                <h3>📊 Monitoring Tools</h3>
                <a href="/prometheus/" class="button">Prometheus Metrics</a>
                <a href="/grafana/" class="button">Grafana Dashboard</a>
            </div>
        </div>
    </div>
</body>
</html>
EOF

# Create monitoring directory and download configurations
mkdir -p /opt/monitoring
cd /opt/monitoring

# Create comprehensive Prometheus configuration
cat > prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "venue_rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
        labels:
          zone: 'Backstage'
          
  - job_name: 'fanwifi'
    static_configs:
      - targets: ['${fanwifi_ip}:9100']
        labels:
          zone: 'FanWiFi'
          tier: 'Public'
          
  - job_name: 'visitorwifi'  
    static_configs:
      - targets: ['${visitorwifi_ip}:9100']
        labels:
          zone: 'VisitorWiFi'
          tier: 'Staff'
          
  - job_name: 'backstage'
    static_configs:
      - targets: ['localhost:9100']
        labels:
          zone: 'Backstage' 
          tier: 'Management'

  # Nginx monitoring
  - job_name: 'nginx-fanwifi'
    static_configs:
      - targets: ['${fanwifi_ip}:8080']
        labels:
          zone: 'FanWiFi'
          service: 'nginx'
          
  - job_name: 'nginx-visitorwifi'
    static_configs:
      - targets: ['${visitorwifi_ip}:8080']
        labels:
          zone: 'VisitorWiFi' 
          service: 'nginx'

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093
EOF

# Create Prometheus alerting rules
cat > venue_rules.yml << 'EOF'
groups:
- name: venue_alerts
  rules:
  - alert: InstanceDown
    expr: up == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Instance {{ $labels.instance }} down"
      description: "{{ $labels.instance }} of job {{ $labels.job }} has been down for more than 1 minute."

  - alert: HighCPUUsage
    expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[2m])) * 100) > 80
    for: 2m
    labels:
      severity: warning
    annotations:
      summary: "High CPU usage on {{ $labels.instance }}"
      description: "CPU usage is above 80% for more than 2 minutes."

  - alert: HighMemoryUsage
    expr: node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100 < 20
    for: 2m  
    labels:
      severity: warning
    annotations:
      summary: "High memory usage on {{ $labels.instance }}"
      description: "Memory usage is above 80% for more than 2 minutes."

  - alert: ChaosEventDetected
    expr: increase(chaos_event_total[5m]) > 0
    for: 0m
    labels:
      severity: info
    annotations:
      summary: "Chaos event detected on {{ $labels.instance }}"
      description: "A chaos engineering event has been triggered on {{ $labels.zone }}."
EOF

# Enhanced docker-compose with Grafana provisioning
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - ./venue_rules.yml:/etc/prometheus/venue_rules.yml
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=30d'
      - '--web.enable-lifecycle'
      - '--web.enable-admin-api'
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
      - GF_INSTALL_PLUGINS=grafana-worldmap-panel,grafana-piechart-panel
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
      - ./grafana/dashboards:/var/lib/grafana/dashboards
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

# Create Grafana provisioning directories
mkdir -p grafana/provisioning/datasources
mkdir -p grafana/provisioning/dashboards  
mkdir -p grafana/dashboards

# Configure Prometheus datasource
cat > grafana/provisioning/datasources/prometheus.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF

# Configure dashboard provisioning
cat > grafana/provisioning/dashboards/venue.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'venue-dashboards'
    orgId: 1
    folder: 'LiveOpsLab'
    folderUid: venue
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
EOF

# Create comprehensive venue monitoring dashboard
cat > grafana/dashboards/venue-overview.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "LiveOpsLab Venue Overview",
    "tags": ["venue", "monitoring"],
    "style": "dark",
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Zone Availability",
        "type": "stat",
        "targets": [
          {
            "expr": "up{job=~\"fanwifi|visitorwifi|backstage\"}",
            "legendFormat": "{{zone}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "mappings": [
              {"options": {"0": {"text": "DOWN", "color": "red"}}, "type": "value"},
              {"options": {"1": {"text": "UP", "color": "green"}}, "type": "value"}
            ],
            "thresholds": {
              "steps": [
                {"color": "red", "value": 0},
                {"color": "green", "value": 1}
              ]
            }
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "CPU Usage by Zone",
        "type": "timeseries",
        "targets": [
          {
            "expr": "100 - (avg by(zone) (rate(node_cpu_seconds_total{mode=\"idle\"}[2m])) * 100)",
            "legendFormat": "{{zone}}"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
      },
      {
        "id": 3,
        "title": "Memory Usage by Zone",
        "type": "timeseries",
        "targets": [
          {
            "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100",
            "legendFormat": "{{zone}}"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8}
      },
      {
        "id": 4,
        "title": "Network Traffic",
        "type": "timeseries", 
        "targets": [
          {
            "expr": "rate(node_network_receive_bytes_total{device!=\"lo\"}[5m])",
            "legendFormat": "{{zone}} - RX"
          },
          {
            "expr": "rate(node_network_transmit_bytes_total{device!=\"lo\"}[5m])",
            "legendFormat": "{{zone}} - TX"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8}
      },
      {
        "id": 5,
        "title": "Chaos Events Timeline",
        "type": "logs",
        "targets": [
          {
            "expr": "{job=\"chaos-events\"}",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 24, "x": 0, "y": 16}
      }
    ],
    "time": {"from": "now-1h", "to": "now"},
    "refresh": "10s"
  }
}
EOF

# Start monitoring stack
/usr/local/bin/docker-compose up -d

# Install CloudWatch Agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Install Prometheus Node Exporter
useradd --no-create-home --shell /bin/false node_exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
tar xzf node_exporter-1.6.1.linux-amd64.tar.gz
cp node_exporter-1.6.1.linux-amd64/node_exporter /usr/local/bin/
chown node_exporter:node_exporter /usr/local/bin/node_exporter

# Create Node Exporter systemd service
cat > /etc/systemd/system/node_exporter.service << 'NODEEOF'
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter --web.listen-address=:9100
Restart=always

[Install]
WantedBy=multi-user.target
NODEEOF

systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter

# Configure CloudWatch Agent for backstage
mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << CWEOF
{
    "agent": {
        "metrics_collection_interval": 30,
        "run_as_user": "cwagent"
    },
    "metrics": {
        "namespace": "LiveOpsLab/${zone_name}",
        "metrics_collected": {
            "cpu": {
                "measurement": ["cpu_usage_idle", "cpu_usage_user", "cpu_usage_system"],
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
            }
        }
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/nginx/access.log",
                        "log_group_name": "/aws/ec2/backstage",
                        "log_stream_name": "nginx-access-{instance_id}"
                    },
                    {
                        "file_path": "/var/log/chaos-events.log", 
                        "log_group_name": "/aws/ec2/chaos-events",
                        "log_stream_name": "backstage-chaos-{instance_id}"
                    }
                ]
            }
        }
    }
}
CWEOF

# Start CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

# Setup log rotation and S3 sync
cat > /etc/logrotate.d/venue-logs << LOGEOF
/var/log/chaos-events.log /var/log/venue-setup.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    postrotate
        aws s3 sync /var/log/ s3://${log_bucket}/logs/backstage/ --exclude "*" --include "*.log*" --region \$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
    endscript
}
LOGEOF

# Configure firewall
systemctl enable iptables
systemctl start iptables
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport 9090 -s 10.0.0.0/16 -j ACCEPT
iptables -A INPUT -p tcp --dport 3000 -s 10.0.0.0/16 -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
service iptables save

# Start services
systemctl start nginx
systemctl enable nginx

# Start monitoring stack
/usr/local/bin/docker-compose up -d

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Setup chaos engineering if enabled
%{ if enable_chaos ~}
echo "Setting up chaos engineering tools..."
curl -o /tmp/setup-chaos.sh "${chaos_scripts_url}/setup-chaos-engineering.sh" || \
wget -O /tmp/setup-chaos.sh "${chaos_scripts_url}/setup-chaos-engineering.sh" || \
echo "Could not download chaos engineering setup script"

if [ -f /tmp/setup-chaos.sh ]; then
    chmod +x /tmp/setup-chaos.sh
    /tmp/setup-chaos.sh
    echo "Chaos engineering setup completed" >> /var/log/venue-setup.log
fi
%{ endif ~}

echo "$(date): Backstage management instance initialized successfully" >> /var/log/venue-setup.log
echo "Access the management portal at http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)" >> /var/log/venue-setup.log
