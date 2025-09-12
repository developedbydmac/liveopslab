# Variables for LiveOpsLab Venue Infrastructure

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "liveopslab-venue"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "fanwifi_subnet_cidr" {
  description = "CIDR block for FanWiFi subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "visitorwifi_subnet_cidr" {
  description = "CIDR block for VisitorWiFi subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "backstage_subnet_cidr" {
  description = "CIDR block for Backstage subnet"
  type        = string
  default     = "10.0.3.0/24"
}

variable "management_cidrs" {
  description = "CIDR blocks allowed for management access"
  type        = list(string)
  default     = ["10.0.3.0/24", "0.0.0.0/0"]  # Add your specific management IPs here
}

variable "ami_id" {
  description = "AMI ID for EC2 instances (Amazon Linux 2)"
  type        = string
  default     = "ami-0c02fb55956c7d316"  # Amazon Linux 2 in us-east-1
}

variable "fanwifi_instance_type" {
  description = "Instance type for FanWiFi server"
  type        = string
  default     = "t3.micro"
}

variable "visitorwifi_instance_type" {
  description = "Instance type for VisitorWiFi server"
  type        = string
  default     = "t3.small"
}

variable "backstage_instance_type" {
  description = "Instance type for Backstage management server"
  type        = string
  default     = "t3.medium"
}

variable "public_key" {
  description = "Public key for EC2 instance access"
  type        = string
  default     = ""  # You'll need to provide your public key
}

# Network Access Control Variables
variable "fan_wifi_bandwidth_limit" {
  description = "Bandwidth limit for fan WiFi in Mbps"
  type        = number
  default     = 10
}

variable "visitor_wifi_bandwidth_limit" {
  description = "Bandwidth limit for visitor WiFi in Mbps"
  type        = number
  default     = 50
}

variable "backstage_bandwidth_limit" {
  description = "Bandwidth limit for backstage network in Mbps"
  type        = number
  default     = 1000
}

# Security and Monitoring Variables
variable "enable_cloudwatch_monitoring" {
  description = "Enable CloudWatch detailed monitoring"
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
}

# Chaos Engineering Variables
variable "enable_chaos_testing" {
  description = "Enable chaos engineering tools installation"
  type        = bool
  default     = false
}

variable "chaos_orchestrator_enabled" {
  description = "Enable automatic chaos orchestrator"
  type        = bool
  default     = false
}

variable "chaos_webhook_port" {
  description = "Port for chaos engineering webhook endpoints"
  type        = number
  default     = 8888
}

variable "chaos_scripts_url" {
  description = "URL for downloading chaos engineering scripts"
  type        = string
  default     = "https://github.com/your-repo/chaos-scripts"
}
