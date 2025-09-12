#!/bin/bash
# Enhanced FanWiFi Instance Initialization with Monitoring
# Installs CloudWatch Agent, Prometheus Node Exporter, and logging

# Update system
yum update -y

# Install required packages
yum install -y nginx htop wget curl net-tools iptables-services python3 python3-pip git jq

# Set hostname
hostnamectl set-hostname ${hostname}

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
cat > /etc/systemd/system/node_exporter.service << 'EOF'
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
EOF

systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter

# Configure CloudWatch Agent
mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
    "agent": {
        "metrics_collection_interval": 30,
        "run_as_user": "cwagent"
    },
    "metrics": {
        "namespace": "LiveOpsLab/${zone_name}",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 30,
                "totalcpu": false
            },
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "diskio": {
                "measurement": [
                    "io_time"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
                "metrics_collection_interval": 30
            },
            "netstat": {
                "measurement": [
                    "tcp_established",
                    "tcp_time_wait"
                ],
                "metrics_collection_interval": 60
            },
            "swap": {
                "measurement": [
                    "swap_used_percent"
                ],
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
                        "log_group_name": "/aws/ec2/fanwifi",
                        "log_stream_name": "nginx-access-{instance_id}",
                        "timezone": "UTC"
                    },
                    {
                        "file_path": "/var/log/nginx/error.log",
                        "log_group_name": "/aws/ec2/fanwifi",
                        "log_stream_name": "nginx-error-{instance_id}",
                        "timezone": "UTC"
                    },
                    {
                        "file_path": "/var/log/chaos-events.log",
                        "log_group_name": "/aws/ec2/chaos-events",
                        "log_stream_name": "fanwifi-chaos-{instance_id}",
                        "timezone": "UTC"
                    },
                    {
                        "file_path": "/var/log/venue-setup.log",
                        "log_group_name": "/aws/ec2/fanwifi",
                        "log_stream_name": "setup-{instance_id}",
                        "timezone": "UTC"
                    }
                ]
            }
        }
    }
}
EOF

# Start CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

# Configure nginx for public WiFi portal
cat > /etc/nginx/conf.d/fanwifi.conf << 'EOF'
server {
    listen 80 default_server;
    server_name _;
    root /var/www/fanwifi;
    index index.html;
    
    # Add monitoring endpoint for Prometheus
    location /metrics {
        proxy_pass http://localhost:9100/metrics;
        allow 10.0.0.0/16;
        deny all;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    # Custom access log format with metrics
    log_format custom_format '$remote_addr - $remote_user [$time_local] '
                            '"$request" $status $body_bytes_sent '
                            '"$http_referer" "$http_user_agent" '
                            'rt=$request_time uct="$upstream_connect_time" '
                            'uht="$upstream_header_time" urt="$upstream_response_time"';
    
    access_log /var/log/nginx/access.log custom_format;
}

# Stub status for nginx monitoring
server {
    listen 8080;
    server_name localhost;
    
    location /nginx_status {
        stub_status on;
        access_log off;
        allow 10.0.0.0/16;
        deny all;
    }
}
EOF

# Create FanWiFi portal
mkdir -p /var/www/fanwifi
cat > /var/www/fanwifi/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🎵 FanWiFi - LiveOpsLab Venue</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: 'Arial', sans-serif; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh; 
            color: white;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .container { 
            max-width: 400px; 
            padding: 40px; 
            background: rgba(255,255,255,0.1); 
            border-radius: 20px; 
            backdrop-filter: blur(10px);
            text-align: center;
            box-shadow: 0 8px 32px rgba(0,0,0,0.3);
        }
        .logo { font-size: 48px; margin-bottom: 20px; }
        h1 { margin-bottom: 10px; font-size: 32px; }
        p { margin-bottom: 30px; opacity: 0.9; }
        .connect-btn { 
            background: #ff6b6b; 
            border: none; 
            padding: 15px 30px; 
            border-radius: 50px; 
            color: white; 
            font-size: 18px; 
            cursor: pointer;
            transition: transform 0.3s;
            width: 100%;
        }
        .connect-btn:hover { transform: translateY(-2px); }
        .status { margin-top: 20px; padding: 10px; border-radius: 10px; background: rgba(76,175,80,0.3); }
        .metrics { margin-top: 20px; font-size: 12px; opacity: 0.7; }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">🎵</div>
        <h1>FanWiFi</h1>
        <p>Welcome to LiveOpsLab Venue<br>High-speed internet for all fans</p>
        <button class="connect-btn" onclick="connectWiFi()">Connect to WiFi</button>
        <div class="status">✅ Network Available - Zone: FanWiFi</div>
        <div class="metrics" id="metrics">Loading metrics...</div>
    </div>
    
    <script>
        function connectWiFi() {
            alert('WiFi connection initiated! Network: FanWiFi-Public');
        }
        
        // Simulate real-time metrics
        function updateMetrics() {
            const users = Math.floor(Math.random() * 50) + 150;
            const uptime = '99.' + Math.floor(Math.random() * 9) + '%';
            document.getElementById('metrics').innerHTML = 
                `Connected Users: $${users} | Uptime: $${uptime} | Zone: FanWiFi`;
        }
        
        updateMetrics();
        setInterval(updateMetrics, 10000);
    </script>
</body>
</html>
EOF

# Configure firewall for monitoring ports
systemctl enable iptables
systemctl start iptables
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport 9100 -s 10.0.0.0/16 -j ACCEPT  # Node Exporter
iptables -A INPUT -p tcp --dport 8080 -s 10.0.0.0/16 -j ACCEPT  # Nginx status
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
service iptables save

# Setup log rotation and S3 sync
cat > /etc/logrotate.d/venue-logs << EOF
/var/log/chaos-events.log /var/log/venue-setup.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    postrotate
        # Sync rotated logs to S3
        aws s3 sync /var/log/ s3://${log_bucket}/logs/fanwifi/ --exclude "*" --include "*.log*" --region \$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
    endscript
}
EOF

# Create chaos event logging function
cat > /usr/local/bin/log-chaos-event.sh << 'EOF'
#!/bin/bash
EVENT_TYPE="$1"
EVENT_STATUS="$2"
EVENT_DETAILS="$3"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

LOG_ENTRY="{\"timestamp\":\"$TIMESTAMP\",\"instance_id\":\"$INSTANCE_ID\",\"zone\":\"FanWiFi\",\"event_type\":\"$EVENT_TYPE\",\"status\":\"$EVENT_STATUS\",\"details\":\"$EVENT_DETAILS\"}"

echo $LOG_ENTRY >> /var/log/chaos-events.log

# Send custom metric to CloudWatch
aws cloudwatch put-metric-data \
    --namespace "LiveOpsLab/ChaosEvents" \
    --metric-data MetricName=ChaosEvent,Value=1,Unit=Count,Dimensions=Zone=FanWiFi,EventType=$EVENT_TYPE,Status=$EVENT_STATUS \
    --region $(curl -s http://169.254.169.254/latest/meta-data/placement/region)
EOF

chmod +x /usr/local/bin/log-chaos-event.sh

# Start services
systemctl start nginx
systemctl enable nginx

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
    /usr/local/bin/log-chaos-event.sh "setup" "completed" "Chaos engineering tools installed"
fi
%{ endif ~}

echo "$(date): FanWiFi instance with monitoring initialized successfully" >> /var/log/venue-setup.log
echo "Access the portal at http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)" >> /var/log/venue-setup.log
echo "Prometheus metrics: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9100/metrics" >> /var/log/venue-setup.log
