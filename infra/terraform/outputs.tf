# Outputs for LiveOpsLab Venue Infrastructure

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.venue_vpc.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.venue_vpc.cidr_block
}

# Subnet Information
output "fanwifi_subnet_id" {
  description = "ID of the FanWiFi subnet"
  value       = aws_subnet.fanwifi_subnet.id
}

output "visitorwifi_subnet_id" {
  description = "ID of the VisitorWiFi subnet"
  value       = aws_subnet.visitorwifi_subnet.id
}

output "backstage_subnet_id" {
  description = "ID of the Backstage subnet"
  value       = aws_subnet.backstage_subnet.id
}

# Instance Information
output "fanwifi_instance_id" {
  description = "ID of the FanWiFi EC2 instance"
  value       = aws_instance.fanwifi_instance.id
}

output "fanwifi_instance_private_ip" {
  description = "Private IP of the FanWiFi EC2 instance"
  value       = aws_instance.fanwifi_instance.private_ip
}

output "fanwifi_instance_public_ip" {
  description = "Public IP of the FanWiFi EC2 instance"
  value       = aws_eip.fanwifi_eip.public_ip
}

output "visitorwifi_instance_id" {
  description = "ID of the VisitorWiFi EC2 instance"
  value       = aws_instance.visitorwifi_instance.id
}

output "visitorwifi_instance_private_ip" {
  description = "Private IP of the VisitorWiFi EC2 instance"
  value       = aws_instance.visitorwifi_instance.private_ip
}

output "visitorwifi_instance_public_ip" {
  description = "Public IP of the VisitorWiFi EC2 instance"
  value       = aws_eip.visitorwifi_eip.public_ip
}

output "backstage_instance_id" {
  description = "ID of the Backstage EC2 instance"
  value       = aws_instance.backstage_instance.id
}

output "backstage_instance_private_ip" {
  description = "Private IP of the Backstage EC2 instance"
  value       = aws_instance.backstage_instance.private_ip
}

output "backstage_instance_public_ip" {
  description = "Public IP of the Backstage EC2 instance"
  value       = aws_eip.backstage_eip.public_ip
}

# Security Group Information
output "fanwifi_security_group_id" {
  description = "ID of the FanWiFi security group"
  value       = aws_security_group.fanwifi_sg.id
}

output "visitorwifi_security_group_id" {
  description = "ID of the VisitorWiFi security group"
  value       = aws_security_group.visitorwifi_sg.id
}

output "backstage_security_group_id" {
  description = "ID of the Backstage security group"
  value       = aws_security_group.backstage_sg.id
}

# Connection Information
output "ssh_connections" {
  description = "SSH connection commands for each instance"
  value = {
    fanwifi     = "ssh -i ~/.ssh/your-key.pem ec2-user@${aws_eip.fanwifi_eip.public_ip}"
    visitorwifi = "ssh -i ~/.ssh/your-key.pem ec2-user@${aws_eip.visitorwifi_eip.public_ip}"
    backstage   = "ssh -i ~/.ssh/your-key.pem ec2-user@${aws_eip.backstage_eip.public_ip}"
  }
}

# Network Summary
output "network_summary" {
  description = "Summary of the venue network setup"
  value = {
    vpc_cidr              = aws_vpc.venue_vpc.cidr_block
    fanwifi_subnet        = aws_subnet.fanwifi_subnet.cidr_block
    visitorwifi_subnet    = aws_subnet.visitorwifi_subnet.cidr_block
    backstage_subnet      = aws_subnet.backstage_subnet.cidr_block
    total_instances       = 3
    network_tiers         = ["Public (FanWiFi)", "Staff (VisitorWiFi)", "Management (Backstage)"]
  }
}

# Monitoring and Logging Outputs
output "monitoring_endpoints" {
  description = "Monitoring and visualization endpoints"
  value = {
    prometheus_url = "http://${aws_eip.backstage_eip.public_ip}:9090"
    grafana_url    = "http://${aws_eip.backstage_eip.public_ip}:3000"
    grafana_login  = "admin / liveopslab123"
  }
}

output "prometheus_targets" {
  description = "Prometheus scraping targets for each zone"
  value = {
    fanwifi_metrics     = "http://${aws_instance.fanwifi_instance.private_ip}:9100/metrics"
    visitorwifi_metrics = "http://${aws_instance.visitorwifi_instance.private_ip}:9100/metrics"
    backstage_metrics   = "http://${aws_instance.backstage_instance.private_ip}:9100/metrics"
  }
}

output "log_storage" {
  description = "S3 bucket for centralized logging"
  value = {
    bucket_name = aws_s3_bucket.venue_logs.bucket
    bucket_arn  = aws_s3_bucket.venue_logs.arn
    log_paths = {
      fanwifi_logs     = "s3://${aws_s3_bucket.venue_logs.bucket}/logs/fanwifi/"
      visitorwifi_logs = "s3://${aws_s3_bucket.venue_logs.bucket}/logs/visitorwifi/"
      backstage_logs   = "s3://${aws_s3_bucket.venue_logs.bucket}/logs/backstage/"
      chaos_events     = "s3://${aws_s3_bucket.venue_logs.bucket}/logs/chaos-events/"
    }
  }
}

output "cloudwatch_log_groups" {
  description = "CloudWatch Log Groups for each zone"
  value = {
    fanwifi_logs     = aws_cloudwatch_log_group.fanwifi_logs.name
    visitorwifi_logs = aws_cloudwatch_log_group.visitorwifi_logs.name
    backstage_logs   = aws_cloudwatch_log_group.backstage_logs.name
    chaos_events     = aws_cloudwatch_log_group.chaos_events.name
  }
}

output "chaos_webhook_endpoints" {
  description = "Chaos engineering webhook endpoints (when enabled)"
  value = var.enable_chaos_testing ? {
    fanwifi_chaos     = "http://${aws_eip.fanwifi_eip.public_ip}:${var.chaos_webhook_port}"
    visitorwifi_chaos = "http://${aws_eip.visitorwifi_eip.public_ip}:${var.chaos_webhook_port}"
    backstage_chaos   = "http://${aws_eip.backstage_eip.public_ip}:${var.chaos_webhook_port}"
  } : {}
}
