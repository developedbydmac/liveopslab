# 🚀 LiveOps Lab - Getting Started Guide

This guide will help you get the LiveOps Lab monitoring platform running locally in just a few minutes.

## **📋 Prerequisites**

Before you begin, make sure you have these installed:

- **Docker & Docker Compose** (required)
- **Python 3.11+** (for local development)
- **Git** (for cloning and version control)
- **4GB+ RAM** (for the full monitoring stack)

### **Installation Check**

```bash
# Verify installations
docker --version          # Should show Docker version 20.0+
docker-compose --version  # Should show version 2.0+
python3 --version         # Should show Python 3.11+
```

## **⚡ Quick Start (5 minutes)**

### **1. Clone and Setup**

```bash
# Clone the repository
git clone https://github.com/developedbydmac/liveopslab.git
cd liveopslab

# Initial setup
make setup
```

### **2. Start All Services**

```bash
# Start the complete monitoring stack
make start

# Wait for services to initialize (30-60 seconds)
# Check status
make status
```

### **3. Access Your Dashboards**

Once started, access these URLs:

| Service | URL | Credentials |
|---------|-----|-------------|
| **Sample Application** | http://localhost:8000 | - |
| **Grafana Dashboards** | http://localhost:3000 | admin / admin |
| **Prometheus Metrics** | http://localhost:9090 | - |
| **Alertmanager** | http://localhost:9093 | - |

### **4. Test Chaos Engineering**

```bash
# Inject HTTP errors for 90 seconds
make chaos

# Watch the dashboards light up with alerts!
```

## **🔍 Detailed Steps**

### **Step 1: Environment Setup**

```bash
# Copy environment template
cp .env.example .env

# Edit environment variables (optional)
nano .env
```

### **Step 2: Build and Start Services**

```bash
# Build Docker images
make build

# Start monitoring stack only (lighter option)
make monitoring

# OR start everything including sample app
make start
```

### **Step 3: Verify Everything is Working**

```bash
# Check service health
curl http://localhost:8000/health

# Check metrics endpoint
curl http://localhost:8000/metrics

# View service logs
make logs
```

### **Step 4: Explore the Platform**

1. **Grafana Dashboard**
   - Go to http://localhost:3000
   - Login with `admin/admin`
   - Navigate to "LiveOps Lab - System Overview" dashboard

2. **Generate Some Data**
   ```bash
   # Create some API traffic
   for i in {1..20}; do curl http://localhost:8000/api/users; done
   
   # Create slow requests
   curl http://localhost:8000/api/slow
   
   # Trigger some errors
   curl http://localhost:8000/api/error
   ```

3. **Run Chaos Experiments**
   ```bash
   # CPU stress test
   make chaos-cpu
   
   # Network latency simulation
   make chaos-latency
   
   # All chaos experiments
   make chaos-all
   ```

## **🛠️ Development Workflow**

### **Local Development**

```bash
# Start development environment
make dev

# Run tests
make test

# Format code
make format

# Run security scans
make security
```

### **Working with Individual Services**

```bash
# Start only monitoring stack
docker-compose up -d prometheus grafana alertmanager

# Start only the sample application
docker-compose up -d sample-app

# View specific service logs
make logs-app
docker-compose logs -f grafana
```

## **🚨 Troubleshooting**

### **Common Issues**

**1. Port Already in Use**
```bash
# Check what's using the port
lsof -i :3000
lsof -i :8000
lsof -i :9090

# Kill conflicting processes or change ports in docker-compose.yml
```

**2. Docker Services Won't Start**
```bash
# Clean up and restart
make clean
make start

# Check Docker resources
docker system df
docker system prune -f
```

**3. Grafana Shows No Data**
```bash
# Verify Prometheus is scraping metrics
curl http://localhost:9090/api/v1/targets

# Check if sample app is generating metrics
curl http://localhost:8000/metrics
```

**4. Permission Denied on Scripts**
```bash
# Make scripts executable
chmod +x docs/chaos-scripts/*.sh
chmod +x deploy.sh
```

### **Service Health Checks**

```bash
# Application health
curl http://localhost:8000/health

# Prometheus health
curl http://localhost:9090/-/healthy

# Grafana health
curl http://localhost:3000/api/health

# Alertmanager health
curl http://localhost:9093/-/healthy
```

## **🌐 Making it Internet-Accessible**

### **Option 1: Local Tunnel (Quickest)**

```bash
# Install ngrok (if not already installed)
brew install ngrok  # macOS
# or download from https://ngrok.com/

# Expose Grafana dashboard to internet
ngrok http 3000

# Expose sample application
ngrok http 8000
```

### **Option 2: Cloud Deployment**

```bash
# Deploy to AWS using Terraform
cd infra/terraform
terraform init
terraform plan
terraform apply

# Or use the make command
make deploy
```

### **Option 3: Docker Hub + Remote Server**

```bash
# Build and push images
docker build -t yourusername/liveopslab-app ./app
docker push yourusername/liveopslab-app

# Deploy on any server with Docker
ssh your-server
docker run -d -p 8000:8000 yourusername/liveopslab-app
```

## **📊 Understanding the Monitoring Stack**

### **Data Flow**

```
Sample App → Prometheus → Grafana
     ↓           ↓          ↑
  /metrics   Alertmanager ←─┘
```

### **Key Metrics to Watch**

- **Request Latency** (50th, 95th, 99th percentiles)
- **Error Rate** (5xx responses / total requests)
- **CPU Usage** (per container and host)
- **Memory Usage** (with thresholds)
- **Active Connections** (concurrent users)

### **Alert Thresholds**

| Metric | Warning | Critical |
|--------|---------|----------|
| Latency (95th) | > 2s | > 5s |
| Error Rate | > 1% | > 5% |
| CPU Usage | > 80% | > 95% |
| Memory Usage | > 85% | > 95% |

## **🎯 Next Steps**

### **Immediate (Next Hour)**

1. ✅ **Start the platform** - `make start`
2. ✅ **Explore dashboards** - Open Grafana
3. ✅ **Run chaos tests** - `make chaos`
4. ✅ **Generate traffic** - Use curl commands above

### **Short Term (This Week)**

1. **Customize Alerts**
   - Edit `monitoring/prometheus/alert.rules.yml`
   - Configure email/Slack in `monitoring/alertmanager/alertmanager.yml`

2. **Add Your Own Services**
   - Modify `docker-compose.yml`
   - Add your application alongside the sample app

3. **Create Custom Dashboards**
   - Build new Grafana dashboards
   - Save them in `monitoring/grafana/dashboards/`

### **Long Term (This Month)**

1. **Production Deployment**
   - Set up AWS infrastructure with Terraform
   - Configure CI/CD pipeline
   - Implement security best practices

2. **Advanced Monitoring**
   - Add distributed tracing with Jaeger
   - Implement log aggregation with Loki
   - Set up synthetic monitoring

3. **Team Integration**
   - Set up on-call rotations
   - Train team on incident response
   - Conduct chaos engineering exercises

## **🆘 Need Help?**

- **Documentation**: Check `/docs` folder for detailed guides
- **Issues**: Open a GitHub issue
- **Community**: Join our discussions
- **Support**: Email support@liveopslab.com

---

**You're ready to monitor everything! 🎉**

Start with `make start` and explore the dashboards. The platform will be running at http://localhost:3000 (Grafana) and http://localhost:8000 (Sample App).
