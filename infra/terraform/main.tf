# LiveOpsLab - Venue Network Infrastructure
# Three-tier network setup for venue operations

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "LiveOpsLab"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "LiveOps-Team"
    }
  }
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC for the venue network
resource "aws_vpc" "venue_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Description = "Main VPC for venue network infrastructure"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "venue_igw" {
  vpc_id = aws_vpc.venue_vpc.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.venue_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.venue_igw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Security Groups for each network tier
resource "aws_security_group" "fanwifi_sg" {
  name_prefix = "${var.project_name}-fanwifi-"
  vpc_id      = aws_vpc.venue_vpc.id
  description = "Security group for FanWiFi network (public access)"

  # Allow HTTP and HTTPS for public access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access"
  }

  # SSH access from management network
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.backstage_subnet.cidr_block]
    description = "SSH from backstage network"
  }

  # Allow ping
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.vpc_cidr]
    description = "ICMP within VPC"
  }

  # Prometheus Node Exporter
  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Prometheus Node Exporter"
  }

  # Nginx status endpoint
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Nginx status endpoint"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-fanwifi-sg"
    NetworkTier = "Public"
  }
}

resource "aws_security_group" "visitorwifi_sg" {
  name_prefix = "${var.project_name}-visitorwifi-"
  vpc_id      = aws_vpc.venue_vpc.id
  description = "Security group for VisitorWiFi network (staff access)"

  # Allow HTTP/HTTPS and additional ports for staff tools
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTP access within VPC"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS access within VPC"
  }

  # SSH access from backstage
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.backstage_subnet.cidr_block]
    description = "SSH from backstage network"
  }

  # Staff application ports
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Staff application port"
  }

  # Allow ping
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.vpc_cidr]
    description = "ICMP within VPC"
  }

  # Prometheus Node Exporter
  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Prometheus Node Exporter"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-visitorwifi-sg"
    NetworkTier = "Staff"
  }
}

resource "aws_security_group" "backstage_sg" {
  name_prefix = "${var.project_name}-backstage-"
  vpc_id      = aws_vpc.venue_vpc.id
  description = "Security group for Backstage network (secured management)"

  # SSH access from specific management IPs
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.management_cidrs
    description = "SSH from management networks"
  }

  # Management ports
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = var.management_cidrs
    description = "RDP access"
  }

  # Monitoring and management tools
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Prometheus monitoring"
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Grafana dashboard"
  }

  # Prometheus Node Exporter
  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Prometheus Node Exporter"
  }

  # Allow ping
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.vpc_cidr]
    description = "ICMP within VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-backstage-sg"
    NetworkTier = "Management"
  }
}

# Subnets for each network tier
resource "aws_subnet" "fanwifi_subnet" {
  vpc_id                  = aws_vpc.venue_vpc.id
  cidr_block              = var.fanwifi_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-fanwifi-subnet"
    NetworkTier = "Public"
    Purpose     = "Fan public WiFi access"
  }
}

resource "aws_subnet" "visitorwifi_subnet" {
  vpc_id                  = aws_vpc.venue_vpc.id
  cidr_block              = var.visitorwifi_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-visitorwifi-subnet"
    NetworkTier = "Staff"
    Purpose     = "Staff and visitor access"
  }
}

resource "aws_subnet" "backstage_subnet" {
  vpc_id                  = aws_vpc.venue_vpc.id
  cidr_block              = var.backstage_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[2]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-backstage-subnet"
    NetworkTier = "Management"
    Purpose     = "Secured backstage operations"
  }
}

# Route table associations
resource "aws_route_table_association" "fanwifi_rta" {
  subnet_id      = aws_subnet.fanwifi_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "visitorwifi_rta" {
  subnet_id      = aws_subnet.visitorwifi_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "backstage_rta" {
  subnet_id      = aws_subnet.backstage_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# EC2 Key Pair for instance access
resource "aws_key_pair" "venue_key" {
  key_name   = "${var.project_name}-key"
  public_key = var.public_key

  tags = {
    Name = "${var.project_name}-key-pair"
  }
}

# EC2 Instances for each network
resource "aws_instance" "fanwifi_instance" {
  ami                    = var.ami_id
  instance_type          = var.fanwifi_instance_type
  key_name               = aws_key_pair.venue_key.key_name
  vpc_security_group_ids = [aws_security_group.fanwifi_sg.id]
  subnet_id              = aws_subnet.fanwifi_subnet.id
  iam_instance_profile   = aws_iam_instance_profile.ec2_monitoring_profile.name

  user_data = base64encode(templatefile("${path.module}/../user_data/fanwifi_init_enhanced.sh", {
    hostname           = "fanwifi-server"
    enable_chaos       = var.enable_chaos_testing
    chaos_scripts_url  = "https://raw.githubusercontent.com/developedbydmac/liveopslab/main/docs/chaos-scripts"
    log_bucket         = aws_s3_bucket.venue_logs.bucket
    zone_name          = "FanWiFi"
  }))

  tags = {
    Name        = "${var.project_name}-fanwifi-instance"
    NetworkTier = "Public"
    Purpose     = "Fan WiFi access point"
    Backup      = "Daily"
    Zone        = "FanWiFi"
    MonitoringEnabled = "true"
  }
}

resource "aws_instance" "visitorwifi_instance" {
  ami                    = var.ami_id
  instance_type          = var.visitorwifi_instance_type
  key_name               = aws_key_pair.venue_key.key_name
  vpc_security_group_ids = [aws_security_group.visitorwifi_sg.id]
  subnet_id              = aws_subnet.visitorwifi_subnet.id
  iam_instance_profile   = aws_iam_instance_profile.ec2_monitoring_profile.name

  user_data = base64encode(templatefile("${path.module}/../user_data/visitorwifi_init.sh", {
    hostname          = "visitorwifi-server"
    enable_chaos      = var.enable_chaos_testing
    chaos_scripts_url = var.chaos_scripts_url
    log_bucket        = aws_s3_bucket.venue_logs.bucket
    zone_name         = "VisitorWiFi"
  }))

  tags = {
    Name        = "${var.project_name}-visitorwifi-instance"
    NetworkTier = "Staff"
    Purpose     = "Staff and visitor WiFi services"
    Backup      = "Daily"
    Zone        = "VisitorWiFi"
    MonitoringEnabled = "true"
  }
}

resource "aws_instance" "backstage_instance" {
  ami                    = var.ami_id
  instance_type          = var.backstage_instance_type
  key_name               = aws_key_pair.venue_key.key_name
  vpc_security_group_ids = [aws_security_group.backstage_sg.id]
  subnet_id              = aws_subnet.backstage_subnet.id
  iam_instance_profile   = aws_iam_instance_profile.ec2_monitoring_profile.name

  user_data = base64encode(templatefile("${path.module}/../user_data/backstage_init_small.sh", {
    hostname          = "backstage-mgmt"
    enable_chaos      = var.enable_chaos_testing
    chaos_scripts_url = var.chaos_scripts_url
    log_bucket        = aws_s3_bucket.venue_logs.bucket
    zone_name         = "Backstage"
    fanwifi_ip        = aws_instance.fanwifi_instance.private_ip
    visitorwifi_ip    = aws_instance.visitorwifi_instance.private_ip
  }))

  tags = {
    Name        = "${var.project_name}-backstage-instance"
    NetworkTier = "Management"
    Purpose     = "Backstage management and monitoring"
    Backup      = "Hourly"
    Critical    = "High"
    Zone        = "Backstage"
    MonitoringEnabled = "true"
  }
}

# Elastic IPs for consistent addressing
resource "aws_eip" "fanwifi_eip" {
  instance = aws_instance.fanwifi_instance.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-fanwifi-eip"
  }

  depends_on = [aws_internet_gateway.venue_igw]
}

resource "aws_eip" "visitorwifi_eip" {
  instance = aws_instance.visitorwifi_instance.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-visitorwifi-eip"
  }

  depends_on = [aws_internet_gateway.venue_igw]
}

resource "aws_eip" "backstage_eip" {
  instance = aws_instance.backstage_instance.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-backstage-eip"
  }

  depends_on = [aws_internet_gateway.venue_igw]
}

# S3 Buckets for Log Storage
resource "aws_s3_bucket" "venue_logs" {
  bucket = "${var.project_name}-venue-logs-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "${var.project_name}-venue-logs"
    Purpose     = "Centralized log storage for venue infrastructure"
    Environment = var.environment
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "venue_logs_versioning" {
  bucket = aws_s3_bucket.venue_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "venue_logs_encryption" {
  bucket = aws_s3_bucket.venue_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "venue_logs_lifecycle" {
  bucket = aws_s3_bucket.venue_logs.id

  rule {
    id     = "log_lifecycle"
    status = "Enabled"

    filter {
      prefix = "logs/"
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}

# IAM Role for CloudWatch and S3 access
resource "aws_iam_role" "ec2_monitoring_role" {
  name = "${var.project_name}-ec2-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-ec2-monitoring-role"
  }
}

resource "aws_iam_role_policy" "ec2_monitoring_policy" {
  name = "${var.project_name}-ec2-monitoring-policy"
  role = aws_iam_role.ec2_monitoring_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "logs:PutLogEvents",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.venue_logs.arn,
          "${aws_s3_bucket.venue_logs.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_monitoring_profile" {
  name = "${var.project_name}-ec2-monitoring-profile"
  role = aws_iam_role.ec2_monitoring_role.name
}

# CloudWatch Log Groups for each zone
resource "aws_cloudwatch_log_group" "fanwifi_logs" {
  name              = "/aws/ec2/fanwifi"
  retention_in_days = var.backup_retention_days

  tags = {
    Name = "${var.project_name}-fanwifi-logs"
    Zone = "FanWiFi"
  }
}

resource "aws_cloudwatch_log_group" "visitorwifi_logs" {
  name              = "/aws/ec2/visitorwifi"
  retention_in_days = var.backup_retention_days

  tags = {
    Name = "${var.project_name}-visitorwifi-logs"
    Zone = "VisitorWiFi"
  }
}

resource "aws_cloudwatch_log_group" "backstage_logs" {
  name              = "/aws/ec2/backstage"
  retention_in_days = var.backup_retention_days

  tags = {
    Name = "${var.project_name}-backstage-logs"
    Zone = "Backstage"
  }
}

resource "aws_cloudwatch_log_group" "chaos_events" {
  name              = "/aws/ec2/chaos-events"
  retention_in_days = var.backup_retention_days

  tags = {
    Name = "${var.project_name}-chaos-events"
    Zone = "All"
  }
}
