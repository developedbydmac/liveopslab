#!/bin/bash
# FanWiFi Instance Initialization Script
# This script sets up the instance for public WiFi access

# Update system
yum update -y

# Install required packages
yum install -y nginx htop wget curl net-tools iptables-services

# Set hostname
hostnamectl set-hostname ${hostname}

# Configure nginx for captive portal
cat > /etc/nginx/conf.d/fanwifi.conf << 'EOF'
server {
    listen 80 default_server;
    server_name _;
    
    location / {
        root /var/www/fanwifi;
        index index.html;
        try_files $uri $uri/ /index.html;
    }
    
    # Captive portal detection
    location /generate_204 {
        return 204;
    }
    
    location /hotspot-detect.html {
        return 200 "<!DOCTYPE html><html><head><title>Success</title></head><body>Success</body></html>";
    }
}
EOF

# Create web directory and captive portal page
mkdir -p /var/www/fanwifi
cat > /var/www/fanwifi/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LiveOpsLab - Fan WiFi</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; background: #f0f0f0; }
        .container { background: white; padding: 30px; border-radius: 10px; max-width: 500px; margin: 0 auto; }
        .logo { font-size: 24px; color: #333; margin-bottom: 20px; }
        button { background: #007cba; color: white; padding: 15px 30px; border: none; border-radius: 5px; font-size: 16px; cursor: pointer; }
        button:hover { background: #005a87; }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">🎵 LiveOpsLab Fan WiFi</div>
        <h2>Welcome to the Venue!</h2>
        <p>Enjoy complimentary internet access during your visit.</p>
        <p><strong>Network:</strong> FanWiFi</p>
        <p><strong>Speed:</strong> Up to 10 Mbps</p>
        <button onclick="window.location.href='http://example.com'">Connect to Internet</button>
        <hr>
        <small>Please use responsibly. Bandwidth is shared among all guests.</small>
    </div>
</body>
</html>
EOF

# Configure firewall for public access
systemctl enable iptables
systemctl start iptables

# Allow HTTP traffic
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -s 10.0.3.0/24 -j ACCEPT
iptables -A INPUT -p icmp -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
service iptables save

# Start and enable services
systemctl start nginx
systemctl enable nginx

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Create log file for monitoring
echo "$(date): FanWiFi instance initialized successfully" >> /var/log/venue-setup.log

# Set up basic monitoring
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
    "metrics": {
        "namespace": "LiveOpsLab/FanWiFi",
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
                        "log_group_name": "/aws/ec2/fanwifi/nginx/access",
                        "log_stream_name": "{instance_id}"
                    },
                    {
                        "file_path": "/var/log/venue-setup.log",
                        "log_group_name": "/aws/ec2/fanwifi/setup",
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

echo "FanWiFi setup completed at $(date)" >> /var/log/venue-setup.log
