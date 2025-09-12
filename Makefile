.PHONY: help setup start stop restart logs status test clean build deploy chaos \
        monitoring security format lint install docker-build docker-clean

# LiveOps Lab - Monitoring and Observability Platform
PROJECT_NAME := liveopslab
DOCKER_COMPOSE := docker-compose
PYTHON := python3
PIP := pip3

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(BLUE)LiveOps Lab - NOC Simulation Platform$(NC)"
	@echo ""
	@echo "$(YELLOW)Available commands:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(YELLOW)Quick start:$(NC)"
	@echo "  make setup    # Initialize the project"
	@echo "  make start    # Start all services"
	@echo "  make chaos    # Run chaos engineering tests"

setup: ## Initialize the project and install dependencies
	@echo "$(BLUE)Setting up LiveOps Lab...$(NC)"
	@cp .env.example .env 2>/dev/null || echo "Environment file already exists"
	@$(PIP) install -r app/requirements.txt 2>/dev/null || echo "Install app dependencies manually if needed"
	@$(PIP) install -r tests/requirements.txt 2>/dev/null || echo "Install test dependencies manually if needed"
	@chmod +x docs/chaos-scripts/*.sh
	@echo "$(GREEN)Setup completed!$(NC)"

install: setup ## Alias for setup

start: ## Start all services using Docker Compose
	@echo "$(BLUE)Starting LiveOps Lab services...$(NC)"
	@$(DOCKER_COMPOSE) up -d
	@echo "$(GREEN)Services started!$(NC)"
	@echo ""
	@echo "$(YELLOW)Access your services:$(NC)"
	@echo "  Application:   http://localhost:8000"
	@echo "  Grafana:       http://localhost:3000 (admin/admin)"
	@echo "  Prometheus:    http://localhost:9090"
	@echo "  Alertmanager:  http://localhost:9093"

stop: ## Stop all services
	@echo "$(BLUE)Stopping services...$(NC)"
	@$(DOCKER_COMPOSE) down
	@echo "$(GREEN)Services stopped$(NC)"

restart: stop start ## Restart all services

status: ## Show service status and health
	@echo "$(BLUE)Service Status:$(NC)"
	@$(DOCKER_COMPOSE) ps
	@echo ""
	@echo "$(BLUE)Health Checks:$(NC)"
	@curl -s http://localhost:8000/health | jq . 2>/dev/null || echo "App: $(RED)Offline$(NC)"

logs: ## Show logs from all services
	@$(DOCKER_COMPOSE) logs -f --tail=100

logs-app: ## Show application logs only
	@$(DOCKER_COMPOSE) logs -f sample-app

build: ## Build Docker images
	@echo "$(BLUE)Building Docker images...$(NC)"
	@$(DOCKER_COMPOSE) build
	@echo "$(GREEN)Build completed$(NC)"

docker-build: build ## Alias for build

test: ## Run tests
	@echo "$(BLUE)Running tests...$(NC)"
	@$(PYTHON) -m pytest tests/ -v --tb=short
	@echo "$(GREEN)Tests completed$(NC)"

test-integration: ## Run integration tests (requires running services)
	@echo "$(BLUE)Running integration tests...$(NC)"
	@$(PYTHON) -m pytest tests/test_app.py::TestMonitoringIntegration -v
	@echo "$(GREEN)Integration tests completed$(NC)"

chaos: ## Run chaos engineering experiments
	@echo "$(BLUE)Running chaos engineering tests...$(NC)"
	@./docs/chaos-scripts/chaos.sh errors
	@echo "$(GREEN)Chaos tests completed$(NC)"

chaos-cpu: ## Run CPU stress test
	@./docs/chaos-scripts/chaos.sh cpu

chaos-latency: ## Run latency injection test
	@./docs/chaos-scripts/chaos.sh latency

chaos-all: ## Run all chaos experiments
	@./docs/chaos-scripts/chaos.sh all

monitoring: ## Start only monitoring stack
	@echo "$(BLUE)Starting monitoring services...$(NC)"
	@$(DOCKER_COMPOSE) up -d prometheus grafana alertmanager
	@echo "$(GREEN)Monitoring stack started$(NC)"

format: ## Format Python code
	@echo "$(BLUE)Formatting code...$(NC)"
	@black app/ tests/ --line-length 88
	@echo "$(GREEN)Code formatted$(NC)"

lint: ## Run code linting
	@echo "$(BLUE)Running linting...$(NC)"
	@flake8 app/ tests/ --max-line-length=88 --extend-ignore=E203,W503
	@black --check app/ tests/ --line-length 88
	@echo "$(GREEN)Linting completed$(NC)"

security: ## Run security scans
	@echo "$(BLUE)Running security scans...$(NC)"
	@safety check --file app/requirements.txt || echo "$(YELLOW)Safety check completed with warnings$(NC)"
	@bandit -r app/ -f json -o security-report.json || echo "$(YELLOW)Bandit scan completed$(NC)"
	@echo "$(GREEN)Security scan completed$(NC)"

deploy-terraform: ## Deploy infrastructure using Terraform
	@echo "$(BLUE)Deploying infrastructure...$(NC)"
	@cd infra/terraform && terraform init && terraform plan && terraform apply
	@echo "$(GREEN)Infrastructure deployed$(NC)"

deploy: deploy-terraform ## Deploy to cloud (alias for deploy-terraform)

clean: ## Clean up Docker resources
	@echo "$(BLUE)Cleaning up...$(NC)"
	@$(DOCKER_COMPOSE) down -v --remove-orphans
	@docker system prune -f
	@find . -name "*.pyc" -delete
	@find . -name "__pycache__" -delete
	@rm -rf .pytest_cache/
	@echo "$(GREEN)Cleanup completed$(NC)"

docker-clean: clean ## Alias for clean

validate: ## Validate configurations
	@echo "$(BLUE)Validating configurations...$(NC)"
	@$(DOCKER_COMPOSE) config > /dev/null && echo "Docker Compose: $(GREEN)Valid$(NC)" || echo "Docker Compose: $(RED)Invalid$(NC)"
	@cd infra/terraform && terraform validate && echo "Terraform: $(GREEN)Valid$(NC)" || echo "Terraform: $(RED)Invalid$(NC)"

demo: ## Run a complete demonstration
	@echo "$(BLUE)Starting LiveOps Lab demonstration...$(NC)"
	@make start
	@sleep 30  # Wait for services to start
	@echo "$(YELLOW)Generating some traffic...$(NC)"
	@for i in {1..10}; do curl -s http://localhost:8000/api/users > /dev/null; done
	@echo "$(YELLOW)Running chaos experiment...$(NC)"
	@./docs/chaos-scripts/chaos.sh --duration 30 errors
	@echo "$(GREEN)Demo completed! Check Grafana dashboards$(NC)"

dev: ## Start development environment
	@make setup
	@make start
	@echo "$(GREEN)Development environment ready!$(NC)"

urls: ## Show important URLs
	@echo "$(YELLOW)LiveOps Lab URLs:$(NC)"
	@echo "  Application:   http://localhost:8000"
	@echo "  Health Check:  http://localhost:8000/health"
	@echo "  Metrics:       http://localhost:8000/metrics"
	@echo "  Grafana:       http://localhost:3000 (admin/admin)"
	@echo "  Prometheus:    http://localhost:9090"
	@echo "  Alertmanager:  http://localhost:9093"

version: ## Show version information
	@echo "$(BLUE)LiveOps Lab v1.0$(NC)"
	@echo "NOC Simulation and Monitoring Platform"
	@echo ""
	@echo "$(YELLOW)Dependencies:$(NC)"
	@docker --version 2>/dev/null || echo "Docker: $(RED)Not installed$(NC)"
	@docker-compose --version 2>/dev/null || echo "Docker Compose: $(RED)Not installed$(NC)"
	@$(PYTHON) --version 2>/dev/null || echo "Python: $(RED)Not installed$(NC)"
