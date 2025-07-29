# LiveOpsLab Venue Infrastructure Makefile
# Simplifies common Terraform operations

.PHONY: help init plan apply destroy validate fmt check clean status ssh-fan ssh-visitor ssh-backstage logs

# Default target
help:
	@echo "LiveOpsLab Venue Infrastructure Management"
	@echo "=========================================="
	@echo ""
	@echo "Available commands:"
	@echo "  init        - Initialize Terraform configuration"
	@echo "  validate    - Validate Terraform configuration"
	@echo "  fmt         - Format Terraform files"
	@echo "  plan        - Create deployment plan"
	@echo "  apply       - Deploy infrastructure"
	@echo "  destroy     - Destroy infrastructure"
	@echo "  status      - Show current infrastructure status"
	@echo "  check       - Validate configuration and show plan"
	@echo ""
	@echo "SSH Access:"
	@echo "  ssh-fan     - SSH to FanWiFi instance"
	@echo "  ssh-visitor - SSH to VisitorWiFi instance"
	@echo "  ssh-backstage - SSH to Backstage instance"
	@echo ""
	@echo "Monitoring:"
	@echo "  logs        - Show recent setup logs from all instances"
	@echo "  urls        - Display access URLs for all portals"
	@echo ""
	@echo "Utilities:"
	@echo "  clean       - Clean Terraform cache and lock files"
	@echo "  backup      - Backup current Terraform state"

# Terraform Operations
init:
	@echo "🚀 Initializing Terraform..."
	terraform init
	@echo "✅ Terraform initialized successfully"

validate:
	@echo "🔍 Validating Terraform configuration..."
	terraform validate
	@echo "✅ Configuration is valid"

fmt:
	@echo "🎨 Formatting Terraform files..."
	terraform fmt -recursive
	@echo "✅ Files formatted successfully"

plan:
	@echo "📋 Creating deployment plan..."
	terraform plan -out=tfplan
	@echo "✅ Plan created successfully"

apply: 
	@echo "🏗️  Deploying infrastructure..."
	@if [ ! -f terraform.tfvars ]; then \
		echo "❌ terraform.tfvars not found. Please copy from terraform.tfvars.example and configure."; \
		exit 1; \
	fi
	terraform apply tfplan
	@echo "✅ Infrastructure deployed successfully"
	@make urls

destroy:
	@echo "🧨 WARNING: This will destroy all infrastructure!"
	@read -p "Are you sure? Type 'yes' to continue: " confirm && [ "$$confirm" = "yes" ]
	terraform destroy
	@echo "✅ Infrastructure destroyed"

# Configuration Management
check: validate fmt plan
	@echo "✅ All checks passed, ready for deployment"

clean:
	@echo "🧹 Cleaning Terraform cache..."
	rm -rf .terraform
	rm -f .terraform.lock.hcl
	rm -f tfplan
	rm -f terraform.tfstate.backup
	@echo "✅ Cache cleaned"

backup:
	@echo "💾 Backing up Terraform state..."
	@mkdir -p backups
	terraform state pull > backups/terraform-state-$(shell date +%Y%m%d-%H%M%S).json
	@echo "✅ State backed up to backups/ directory"

# Infrastructure Status
status:
	@echo "📊 Infrastructure Status"
	@echo "======================="
	@if terraform state list > /dev/null 2>&1; then \
		echo "Resources deployed:"; \
		terraform state list | wc -l | xargs echo "  Total resources:"; \
		echo ""; \
		echo "Instances:"; \
		terraform state list | grep aws_instance | sed 's/aws_instance\./  /' | sed 's/_/ /g'; \
		echo ""; \
		echo "Public IPs:"; \
		terraform output -json | jq -r '. | to_entries[] | select(.key | endswith("_public_ip")) | "  \(.key): \(.value.value)"' 2>/dev/null || echo "  Run 'terraform apply' first"; \
	else \
		echo "❌ No infrastructure deployed. Run 'make apply' first."; \
	fi

urls:
	@echo "🌐 Access URLs"
	@echo "=============="
	@terraform output -json 2>/dev/null | jq -r '
		"FanWiFi Portal:     http://" + (.fanwifi_instance_public_ip.value // "NOT_DEPLOYED"),
		"Staff Portal:       http://" + (.visitorwifi_instance_public_ip.value // "NOT_DEPLOYED"),
		"Management Console: http://" + (.backstage_instance_public_ip.value // "NOT_DEPLOYED"),
		"",
		"Monitoring Tools:",
		"  Prometheus:       http://" + (.backstage_instance_public_ip.value // "NOT_DEPLOYED") + "/prometheus/",
		"  Grafana:          http://" + (.backstage_instance_public_ip.value // "NOT_DEPLOYED") + "/grafana/"
	' || echo "❌ Infrastructure not deployed. Run 'make apply' first."

# SSH Access
ssh-fan:
	@echo "🔑 Connecting to FanWiFi instance..."
	@FAN_IP=$$(terraform output -raw fanwifi_instance_public_ip 2>/dev/null); \
	if [ -n "$$FAN_IP" ]; then \
		ssh -i ~/.ssh/liveopslab-key ec2-user@$$FAN_IP; \
	else \
		echo "❌ FanWiFi instance not found. Deploy infrastructure first."; \
	fi

ssh-visitor:
	@echo "🔑 Connecting to VisitorWiFi instance..."
	@VISITOR_IP=$$(terraform output -raw visitorwifi_instance_public_ip 2>/dev/null); \
	if [ -n "$$VISITOR_IP" ]; then \
		ssh -i ~/.ssh/liveopslab-key ec2-user@$$VISITOR_IP; \
	else \
		echo "❌ VisitorWiFi instance not found. Deploy infrastructure first."; \
	fi

ssh-backstage:
	@echo "🔑 Connecting to Backstage instance..."
	@BACKSTAGE_IP=$$(terraform output -raw backstage_instance_public_ip 2>/dev/null); \
	if [ -n "$$BACKSTAGE_IP" ]; then \
		ssh -i ~/.ssh/liveopslab-key ec2-user@$$BACKSTAGE_IP; \
	else \
		echo "❌ Backstage instance not found. Deploy infrastructure first."; \
	fi

# Monitoring and Logs
logs:
	@echo "📝 Recent Setup Logs"
	@echo "==================="
	@for instance in fanwifi visitorwifi backstage; do \
		echo ""; \
		echo "=== $$instance ==="; \
		IP=$$(terraform output -raw $${instance}_instance_public_ip 2>/dev/null); \
		if [ -n "$$IP" ]; then \
			ssh -i ~/.ssh/liveopslab-key -o ConnectTimeout=5 ec2-user@$$IP \
				"tail -10 /var/log/venue-setup.log 2>/dev/null || echo 'Log not available yet'" 2>/dev/null || \
				echo "Cannot connect to $$instance instance"; \
		else \
			echo "Instance not deployed"; \
		fi; \
	done

# Development helpers
dev-setup:
	@echo "🛠️  Setting up development environment..."
	@if [ ! -f terraform.tfvars ]; then \
		cp terraform.tfvars.example terraform.tfvars; \
		echo "📝 Created terraform.tfvars from example"; \
		echo "⚠️  Please edit terraform.tfvars with your configuration"; \
	fi
	@if [ ! -f ~/.ssh/liveopslab-key ]; then \
		echo "🔐 Generating SSH key pair..."; \
		ssh-keygen -t rsa -b 4096 -f ~/.ssh/liveopslab-key -N ""; \
		echo "📝 Add this public key to your terraform.tfvars:"; \
		echo ""; \
		cat ~/.ssh/liveopslab-key.pub; \
		echo ""; \
	fi
	@echo "✅ Development environment ready"

# All-in-one deployment
deploy: init check apply
	@echo "🎉 Deployment completed successfully!"
	@echo ""
	@make urls

# Quick status check
quick-check:
	@echo "⚡ Quick Status Check"
	@echo "===================="
	@echo "Terraform: $$(terraform version --json | jq -r '.terraform_version' 2>/dev/null || echo 'Not installed')"
	@echo "AWS CLI: $$(aws --version 2>/dev/null | cut -d' ' -f1 || echo 'Not installed')"
	@echo "Config file: $$([ -f terraform.tfvars ] && echo '✅ Found' || echo '❌ Missing')"
	@echo "SSH key: $$([ -f ~/.ssh/liveopslab-key ] && echo '✅ Found' || echo '❌ Missing')"
	@echo ""
	@if [ -f terraform.tfvars ] && [ -f ~/.ssh/liveopslab-key ]; then \
		echo "🚀 Ready for deployment!"; \
	else \
		echo "⚠️  Run 'make dev-setup' to configure your environment"; \
	fi
