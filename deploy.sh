#!/bin/bash
# LiveOpsLab Quick Deploy Script
# This script automates the initial setup and deployment

set -e  # Exit on any error

echo "🎵 LiveOpsLab Venue Infrastructure Deployment"
echo "============================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
print_status "Checking prerequisites..."

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed. Please install Terraform first."
    echo "Visit: https://learn.hashicorp.com/tutorials/terraform/install-cli"
    exit 1
fi

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install AWS CLI first."
    echo "Visit: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS credentials not configured. Please run 'aws configure' first."
    exit 1
fi

print_success "Prerequisites check passed!"

# Setup configuration
print_status "Setting up configuration..."

if [ ! -f terraform.tfvars ]; then
    cp terraform.tfvars.example terraform.tfvars
    print_success "Created terraform.tfvars from example"
    
    # Get current user's IP for management access
    CURRENT_IP=$(curl -s https://api.ipify.org 2>/dev/null || echo "0.0.0.0")
    if [ "$CURRENT_IP" != "0.0.0.0" ]; then
        sed -i.bak "s/203\.0\.113\.0\/24/${CURRENT_IP}\/32/" terraform.tfvars
        print_success "Updated management_cidrs with your current IP: $CURRENT_IP"
    fi
else
    print_warning "terraform.tfvars already exists, skipping creation"
fi

# Setup SSH key
SSH_KEY_PATH="$HOME/.ssh/liveopslab-key"
if [ ! -f "$SSH_KEY_PATH" ]; then
    print_status "Generating SSH key pair..."
    ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N "" -C "liveopslab-venue"
    chmod 600 "$SSH_KEY_PATH"
    chmod 644 "${SSH_KEY_PATH}.pub"
    
    # Update terraform.tfvars with the public key
    PUBLIC_KEY=$(cat "${SSH_KEY_PATH}.pub")
    if grep -q "^public_key.*=" terraform.tfvars; then
        sed -i.bak "s|^public_key.*=.*|public_key = \"$PUBLIC_KEY\"|" terraform.tfvars
    else
        echo "public_key = \"$PUBLIC_KEY\"" >> terraform.tfvars
    fi
    
    print_success "SSH key generated and added to configuration"
else
    print_warning "SSH key already exists at $SSH_KEY_PATH"
fi

# Get AWS region
AWS_REGION=$(aws configure get region 2>/dev/null || echo "us-east-1")
sed -i.bak "s/aws_region.*=.*/aws_region = \"$AWS_REGION\"/" terraform.tfvars
print_success "Set AWS region to: $AWS_REGION"

# Interactive configuration review
echo ""
print_status "Configuration Review"
echo "===================="
echo "Project: $(grep project_name terraform.tfvars | cut -d'"' -f2)"
echo "Region: $(grep aws_region terraform.tfvars | cut -d'"' -f2)"
echo "Environment: $(grep environment terraform.tfvars | cut -d'"' -f2)"
echo ""

read -p "Do you want to review/edit the configuration? (y/N): " review_config
if [[ $review_config =~ ^[Yy]$ ]]; then
    ${EDITOR:-nano} terraform.tfvars
fi

# Terraform deployment
print_status "Starting Terraform deployment..."

print_status "Initializing Terraform..."
terraform init

print_status "Validating configuration..."
terraform validate

print_status "Creating deployment plan..."
terraform plan -out=tfplan

echo ""
print_warning "About to deploy AWS infrastructure. This will incur costs!"
echo "Estimated monthly cost: ~\$40-60 USD"
echo ""
read -p "Continue with deployment? (y/N): " confirm_deploy

if [[ ! $confirm_deploy =~ ^[Yy]$ ]]; then
    print_warning "Deployment cancelled by user"
    exit 0
fi

print_status "Applying Terraform configuration..."
terraform apply tfplan

print_success "Deployment completed successfully!"

# Display access information
echo ""
echo "🎉 LiveOpsLab Venue Infrastructure is Ready!"
echo "==========================================="
echo ""

# Get outputs
FAN_IP=$(terraform output -raw fanwifi_instance_public_ip 2>/dev/null || echo "Not available")
VISITOR_IP=$(terraform output -raw visitorwifi_instance_public_ip 2>/dev/null || echo "Not available")
BACKSTAGE_IP=$(terraform output -raw backstage_instance_public_ip 2>/dev/null || echo "Not available")

echo "📱 Access URLs:"
echo "  FanWiFi Portal:      http://$FAN_IP"
echo "  Staff Portal:        http://$VISITOR_IP"
echo "  Management Console:  http://$BACKSTAGE_IP"
echo ""
echo "🔧 Monitoring Tools:"
echo "  Prometheus:          http://$BACKSTAGE_IP/prometheus/"
echo "  Grafana:             http://$BACKSTAGE_IP/grafana/"
echo "    (admin/liveopslab123)"
echo ""
echo "🔑 SSH Access:"
echo "  FanWiFi:     ssh -i ~/.ssh/liveopslab-key ec2-user@$FAN_IP"
echo "  VisitorWiFi: ssh -i ~/.ssh/liveopslab-key ec2-user@$VISITOR_IP"
echo "  Backstage:   ssh -i ~/.ssh/liveopslab-key ec2-user@$BACKSTAGE_IP"
echo ""

# Wait for services to start
print_status "Waiting for services to initialize (this may take 2-3 minutes)..."
sleep 30

# Check if services are responding
print_status "Checking service availability..."
for i in {1..6}; do
    echo -n "."
    sleep 30
done
echo ""

# Test connectivity
services_ready=0
if curl -s --connect-timeout 10 "http://$FAN_IP" > /dev/null; then
    print_success "FanWiFi portal is responding"
    ((services_ready++))
else
    print_warning "FanWiFi portal not yet available"
fi

if curl -s --connect-timeout 10 "http://$VISITOR_IP" > /dev/null; then
    print_success "Staff portal is responding"
    ((services_ready++))
else
    print_warning "Staff portal not yet available"
fi

if curl -s --connect-timeout 10 "http://$BACKSTAGE_IP" > /dev/null; then
    print_success "Management console is responding"
    ((services_ready++))
else
    print_warning "Management console not yet available"
fi

echo ""
if [ $services_ready -eq 3 ]; then
    print_success "All services are ready! 🎉"
else
    print_warning "Some services are still starting up. They should be available in a few minutes."
fi

echo ""
echo "📚 Next Steps:"
echo "1. Visit the portals in your browser"
echo "2. Check the management console for system status"
echo "3. Review the README.md for detailed documentation"
echo "4. Use 'make status' to check infrastructure status"
echo ""

print_warning "Remember to run 'terraform destroy' when you're done to avoid ongoing charges!"

echo ""
print_success "Deployment script completed! Enjoy your LiveOpsLab venue infrastructure! 🎵"
