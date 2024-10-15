
# VPC Configuration
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name        = "${var.prefix}-VPC"
    Environment = var.environment
  }
}
# Subnet Configurations
## Public Subnets
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index + 2}.0/24"
  availability_zone       = element(["us-west-1a", "us-west-1b"], count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.prefix}-PublicSubnet${count.index == 0 ? "" : "B"}"
  }
}
## Private Subnets
resource "aws_subnet" "private" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 3}.0/24"
  availability_zone = element(["us-west-1a", "us-west-1b"], count.index)
  tags = {
    Name = "${var.prefix}${count.index == 1 ? "App" : count.index == 2 ? "DB" : ""}PrivateSubnet${count.index == 1 ? "B" : ""}"
  }
}
# Internet Gateway Configuration
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.prefix}-IGW"
  }
}
# Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}
# NAT Gateway Configuration
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public[0].id
  tags = {
    Name = "${var.prefix}-NATGateway"
  }
}
# Route Table Configurations
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "${var.prefix}-PublicRouteTable"
  }
}
resource "aws_route_table_association" "public_association" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
# Route Table for Private Subnets
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name = "${var.prefix}-PrivateRouteTable"
  }
}
# Route Table Associations for Private Subnets
resource "aws_route_table_association" "private_association" {
  count          = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
# Database Subnet Group
resource "aws_db_subnet_group" "default" {
  name       = "${lower(var.prefix)}-db-subnet-group"  
  subnet_ids = [aws_subnet.private[1].id, aws_subnet.private[0].id]
  tags = {
    Name = "${lower(var.prefix)}-DBSubnetGroup"  
  }
}
# Load Balancer Configuration
resource "aws_lb" "app_lb" {
  name                       = "${var.prefix}-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb_sg.id]
  subnets                    = aws_subnet.public[*].id
  enable_deletion_protection = false
  tags = {
    Name = "${var.prefix}-ALB"
  }
}
# Target Group Configuration
resource "aws_lb_target_group" "app_tg" {
  name     = "${var.prefix}-app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  tags = {
    Name = "${var.prefix}-AppTargetGroup"
  }
}
# Route 53 Configuration
resource "aws_route53_zone" "main" {
  name = "GuildofCloud.com" 
}
resource "aws_route53_record" "alb" {
  zone_id = aws_route53_zone.main.id
  name    = "www.GOGreendomain.com"  # Change to your desired subdomain
  type    = "A"
  alias {
    name                   = aws_lb.app_lb.dns_name
    zone_id                = aws_lb.app_lb.zone_id
    evaluate_target_health = true
  }
}
# S3 Buckets Configuration
resource "aws_s3_bucket" "static_assets" {
  bucket = "${lower(var.prefix)}-static-assets"
  tags = {
    Name = "${var.prefix}-StaticAssets"
  }
}
# Enable Versioning for static assets bucket
resource "aws_s3_bucket_versioning" "static_assets_versioning" {
  bucket = aws_s3_bucket.static_assets.id
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket" "archival_bucket" {
  bucket = "${lower(var.prefix)}-archive-bucket"
  tags = {
    Name = "${var.prefix}-ArchiveBucket"
  }
}
# Enable Versioning for archival bucket
resource "aws_s3_bucket_versioning" "archival_bucket_versioning" {
  bucket = aws_s3_bucket.archival_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}
# S3 Bucket Lifecycle Configuration
resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  bucket = aws_s3_bucket.archival_bucket.id
  rule {
    id     = "MoveToGlacier"
    status = "Enabled"
    transition {
      days          = 30
      storage_class = "GLACIER"
    }
    expiration {
      days = 365
    }
  }
}
# IAM Role for S3 Replication
resource "aws_iam_role" "replication_role" {
  name = "${var.prefix}-S3ReplicationRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "s3.amazonaws.com"
        },
        Action = "sts:AssumeRole",
      },
    ],
  })
}
# S3 Replication Configuration
resource "aws_s3_bucket_replication_configuration" "static_assets_replication" {
  bucket = aws_s3_bucket.static_assets.id
  role   = aws_iam_role.replication_role.arn
  rule {
    id     = "replicate-static-assets"
    status = "Enabled"
    destination {
      bucket        = aws_s3_bucket.archival_bucket.arn
      storage_class = "GLACIER"
    }
  }
}
# IAM Policy for S3 Replication
resource "aws_iam_role_policy" "replication_policy" {
  name = "${var.prefix}-s3-replication-policy"
  role = aws_iam_role.replication_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
        ],
        Effect = "Allow",
        Resource = [
          aws_s3_bucket.static_assets.arn,
          "${aws_s3_bucket.static_assets.arn}/*", # Allows access to all objects in this bucket
        ],
      },
      {
        Action = [
          "s3:PutObject",
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
        ],
        Effect = "Allow",
        Resource = [
          aws_s3_bucket.archival_bucket.arn,
          "${aws_s3_bucket.archival_bucket.arn}/*", # Allows access to all objects in the destination bucket
        ],
      },
    ],
  })
}
# SNS Topic
resource "aws_sns_topic" "critical_alerts" {
  name = "${var.prefix}-CriticalEventAlerts"
}
# SNS Topic Subscription (for Email)
resource "aws_sns_topic_subscription" "critical_alerts_email" {
  topic_arn = aws_sns_topic.critical_alerts.arn
  protocol  = "email"
  endpoint  = "damirxon27@gmail.com"  # Change to your desired email
}
# CloudWatch Alarms
## High CPU Alarm for EC2
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.prefix}-HighCPUAlarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_actions       = [aws_sns_topic.critical_alerts.arn]
}
## High DB Connections Alarm
resource "aws_cloudwatch_metric_alarm" "high_db_connections" {
  alarm_name          = "${var.prefix}-HighDBConnections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "100"
  alarm_description = "Triggers when DB connections exceed 100."
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.default.id  # Make sure aws_db_instance.default is defined
  }
  alarm_actions = [aws_sns_topic.critical_alerts.arn]
}
## HTTP 400 Errors Alarm
resource "aws_cloudwatch_metric_alarm" "http_error_alarm" {
  alarm_name          = "${var.prefix}-HTTP400ErrorsAlarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "4XXError"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 100
  alarm_description = "Alarm when there are more than 100 HTTP 400 errors in a minute"
  dimensions = {
    LoadBalancer = aws_lb.app_lb.arn
  }
  alarm_actions = [aws_sns_topic.critical_alerts.arn]
}
# Output SNS Topic ARN
output "sns_topic_arn" {
  value = aws_sns_topic.critical_alerts.arn
}