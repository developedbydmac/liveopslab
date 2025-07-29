# 🏟️ LiveOpsLab - AI-Powered Venue Network Management

[![CI/CD Pipeline](https://github.com/developedbydmac/liveopslab/actions/workflows/deploy.yml/badge.svg)](https://github.com/developedbydmac/liveopslab/actions/workflows/deploy.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python 3.11+](https://img.shields.io/badge/python-3.11+-blue.svg)](https://www.python.org/downloads/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.104+-green.svg)](https://fastapi.tiangolo.com/)
[![Terraform](https://img.shields.io/badge/Terraform-1.0+-purple.svg)](https://terraform.io/)

## 🎯 Overview

LiveOpsLab is a comprehensive incident management platform designed for venue network operations. It combines infrastructure automation, chaos engineering, and AI-powered root cause analysis to ensure maximum uptime for critical venue services like fan WiFi, staff networks, and backstage operations.

## 🏗️ Architecture Overview

### Network Tiers

1. **FanWiFi (Public Network)**
   - **Purpose**: Free public WiFi for venue guests
   - **Subnet**: `10.0.1.0/24`
   - **Features**: Basic internet access, captive portal, bandwidth limits
   - **Security**: Minimal restrictions, public access

2. **VisitorWiFi (Staff Network)**
   - **Purpose**: Enhanced access for staff and VIP visitors
   - **Subnet**: `10.0.2.0/24`
   - **Features**: Higher bandwidth, staff applications, priority access
   - **Security**: VPC-restricted access, staff tools

3. **Backstage (Management Network)**
   - **Purpose**: Secured network for venue management and operations
   - **Subnet**: `10.0.3.0/24`
   - **Features**: Full access, monitoring tools, management dashboard
   - **Security**: Restricted access, management-only ports

### Infrastructure Components

- **VPC**: `10.0.0.0/16` with Internet Gateway
- **3 Subnets**: One for each network tier across different AZs
- **3 EC2 Instances**: Dedicated server for each network
- **Security Groups**: Tier-specific firewall rules
- **Elastic IPs**: Consistent public addressing
- **Monitoring**: CloudWatch integration and Prometheus/Grafana stack

## 🚀 Quick Start

### Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** installed (>= 1.0)
3. **AWS CLI** configured with credentials
4. **SSH Key Pair** for instance access

### Installation Steps

1. **Clone and Setup**
   ```bash
   git clone <repository-url>
   cd liveopslab
   ```

2. **Configure Variables**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your specific values
   ```

3. **Generate SSH Key** (if needed)
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/liveopslab-key
   # Add the public key content to terraform.tfvars
   ```

4. **Deploy Infrastructure**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

5. **Access Your Infrastructure**
   - **FanWiFi Portal**: `http://<fanwifi-ip>`
   - **Staff Portal**: `http://<visitorwifi-ip>`
   - **Management Console**: `http://<backstage-ip>`

## 🛠️ Configuration

### Required Variables

Edit `terraform.tfvars` with your values:

```hcl
# Basic Configuration
aws_region   = "us-east-1"
project_name = "liveopslab-venue"
environment  = "dev"

# SSH Access
public_key = "ssh-rsa AAAAB3NzaC1yc2E... your-public-key-here"

# Security
management_cidrs = [
  "10.0.3.0/24",        # Backstage subnet
  "203.0.113.0/24"      # Your office/home IP range
]
```

### Network Customization

```hcl
# Network Configuration
vpc_cidr                  = "10.0.0.0/16"
fanwifi_subnet_cidr      = "10.0.1.0/24"
visitorwifi_subnet_cidr  = "10.0.2.0/24"
backstage_subnet_cidr    = "10.0.3.0/24"

# Performance Settings
fanwifi_instance_type      = "t3.micro"    # Cost-effective
visitorwifi_instance_type  = "t3.small"    # Medium performance
backstage_instance_type    = "t3.medium"   # High performance
```

## 📊 Monitoring and Management

### Built-in Monitoring

Each instance includes:
- **CloudWatch Agent**: System metrics and logs
- **Custom Dashboards**: Network-specific monitoring
- **Log Aggregation**: Centralized logging

### Backstage Management Tools

Access via `http://<backstage-ip>`:
- **Prometheus**: Metrics collection (`/prometheus/`)
- **Grafana**: Visualization dashboards (`/grafana/`)
- **System Status**: Real-time infrastructure monitoring
- **Network Control**: Centralized management interface

Default Grafana credentials:
- **Username**: `admin`
- **Password**: `liveopslab123`

## ⚡ Chaos Engineering

This infrastructure includes integrated chaos engineering capabilities to test system resilience and improve operational readiness.

### Features
- **Network Interface Failures**: Simulate AP disconnections and connectivity issues
- **Network Latency/Packet Loss**: Test degraded network conditions  
- **CPU Spikes**: Generate system load to test performance under stress
- **Automated Orchestration**: Schedule chaos events or trigger via webhooks
- **Comprehensive Monitoring**: CloudWatch, Prometheus, and syslog integration

### Configuration

Enable chaos engineering in your `terraform.tfvars`:

```hcl
enable_chaos_testing = true
chaos_orchestrator_enabled = true
chaos_scripts_url = "https://raw.githubusercontent.com/your-repo/chaos-scripts/main"
```

### Chaos Tools

Located in `/opt/chaos-scripts/` on each instance:

- **`ap-failure-simulator.sh`** - Network interface failures
- **`network-latency-simulator.sh`** - Network degradation simulation
- **`cpu-spike-simulator.sh`** - CPU load generation  
- **`chaos-orchestrator.sh`** - Automated chaos scheduling

### Manual Chaos Triggers

```bash
# Trigger AP failure (3 minute outage)
sudo /opt/chaos-scripts/ap-failure-simulator.sh

# Add network latency (100ms, 5% packet loss, 2 minutes)
sudo /opt/chaos-scripts/network-latency-simulator.sh --latency 100ms --loss 5% --duration 120

# Generate CPU spike (80% load across 4 cores, 90 seconds)
sudo /opt/chaos-scripts/cpu-spike-simulator.sh --load 80 --cores 4 --duration 90
```

### Webhook Endpoints

When orchestrator is enabled, trigger chaos via HTTP:

```bash
# Trigger AP failure
curl -X POST http://<instance-ip>:8888/chaos/ap-failure

# Trigger network latency
curl -X POST http://<instance-ip>:8888/chaos/network-latency

# Trigger CPU spike  
curl -X POST http://<instance-ip>:8888/chaos/cpu-spike

# Get chaos status
curl http://<instance-ip>:8888/status
```

## 🔐 Security Features

### Network Segmentation
- **Public Tier**: Internet access with limited internal connectivity
- **Staff Tier**: VPC-wide access with enhanced features
- **Management Tier**: Full access with administrative privileges

### Security Groups
- **Principle of Least Privilege**: Minimal required access
- **Tier-based Rules**: Network-specific restrictions  
- **Management Access**: SSH restricted to backstage network

### Access Control
- **SSH Keys**: Key-based authentication
- **IP Whitelisting**: Management IP restrictions
- **Internal Communication**: Secure inter-tier connectivity

## 📱 User Experience

### FanWiFi (Public)
- **Captive Portal**: Welcome page with terms
- **Bandwidth Management**: Fair usage limits
- **Simple Interface**: Easy connection process

### VisitorWiFi (Staff)
- **Enhanced Portal**: Staff-specific features
- **Application Access**: Internal tools and dashboards
- **Priority Bandwidth**: Higher speed allocation

### Backstage (Management)
- **Full Control Panel**: Complete infrastructure management
- **Real-time Monitoring**: Live system metrics
- **Administrative Tools**: User management and system control

## 🔧 Maintenance

### Regular Tasks

1. **Update Systems**
   ```bash
   # SSH to each instance
   ssh -i ~/.ssh/liveopslab-key ec2-user@<instance-ip>
   sudo yum update -y
   ```

2. **Monitor Logs**
   ```bash
   # Check setup logs
   tail -f /var/log/venue-setup.log
   
   # Check application logs
   tail -f /var/log/nginx/access.log
   ```

3. **Backup Configuration**
   ```bash
   # Export Terraform state
   terraform state pull > backup-$(date +%Y%m%d).tfstate
   ```

### Scaling Considerations

- **Instance Types**: Upgrade based on usage patterns
- **Load Balancing**: Add ALB for high availability
- **Auto Scaling**: Implement ASG for dynamic scaling
- **Multi-AZ**: Deploy across multiple availability zones

## 💰 Cost Optimization

### Current Architecture Cost (us-east-1, approximate)
- **3 × EC2 Instances**: ~$25-45/month
- **3 × Elastic IPs**: ~$11/month  
- **Data Transfer**: Variable based on usage
- **CloudWatch**: ~$5-10/month

### Cost Reduction Strategies
1. **Reserved Instances**: 30-60% savings for long-term usage
2. **Spot Instances**: 50-90% savings for non-critical workloads
3. **Instance Scheduling**: Stop instances during off-hours
4. **Right-sizing**: Monitor and adjust instance types

## 🚨 Troubleshooting

### Common Issues

1. **Cannot Connect to Instances**
   - Check security group rules
   - Verify SSH key configuration
   - Confirm Elastic IP association

2. **Web Portals Not Loading**
   - Check nginx status: `sudo systemctl status nginx`
   - Review firewall rules: `sudo iptables -L`
   - Check instance logs: `tail -f /var/log/venue-setup.log`

3. **Monitoring Not Working**
   - Verify Docker services: `docker ps`
   - Check CloudWatch agent: `sudo systemctl status amazon-cloudwatch-agent`
   - Review Prometheus targets: `http://<backstage-ip>/prometheus/targets`

### Log Locations

- **Setup Logs**: `/var/log/venue-setup.log`
- **Web Server**: `/var/log/nginx/`
- **System Logs**: `/var/log/messages`
- **Application Logs**: Service-specific locations

## 🧹 Cleanup

To destroy the infrastructure:

```bash
terraform destroy
```

**Note**: This will permanently delete all resources. Ensure you have backed up any important data.

## 📞 Support

For issues or questions:
1. Check the troubleshooting section above
2. Review AWS CloudWatch logs
3. Check Terraform documentation
4. Contact your system administrator

## 🤝 Contributing

This configuration is designed to be modular and extensible:
- Add new network tiers by duplicating the subnet/instance pattern
- Enhance security with WAF or additional security groups
- Integrate with external monitoring systems
- Add database tiers for application data

## 📄 License

This project is provided as-is for educational and demonstration purposes.

---

**LiveOpsLab** - Simulating real-world venue operations infrastructure 🎵
