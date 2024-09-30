provider "aws" {
  region = "us-west-1"
}

# VPC Configuration
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "GoGreenVPC"
  }
}

# Subnet Configurations
# Public Subnets
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-west-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "GoGreenPublicSubnet"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-west-1b"
  tags = {
    Name = "GoGreenPublicSubnetB"
  }
}

# Private Subnets
resource "aws_subnet" "app_private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-west-1a"
  tags = {
    Name = "GoGreenAppPrivateSubnet"
  }
}

resource "aws_subnet" "app_private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-west-1b"
  tags = {
    Name = "GoGreenAppPrivateSubnetB"
  }
}

resource "aws_subnet" "db_private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = "us-west-1a"
  tags = {
    Name = "GoGreenDBPrivateSubnet"
  }
}

# Internet Gateway Configuration
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "GoGreenIGW"
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
    Name = "GoGreenPublicRouteTable"
  }
}

resource "aws_route_table_association" "public_association_a" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_association_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

# NAT Gateway Configuration
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public.id
  tags = {
    Name = "GoGreenNATGateway"
  }
}

# Route Table for Private Subnets
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name = "GoGreenPrivateRouteTable"
  }
}

# Route Table Associations for Private Subnets
resource "aws_route_table_association" "app_private_association" {
  subnet_id      = aws_subnet.app_private.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "app_private_association_b" {
  subnet_id      = aws_subnet.app_private_b.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "db_private_association" {
  subnet_id      = aws_subnet.db_private.id
  route_table_id = aws_route_table.private.id
}

# Bastion Host Configuration
resource "aws_instance" "bastion" {
  ami           = "ami-047d7c33f6e7b4bc4"
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public.id
  key_name      = "your_key_pair_name"
  security_groups = [aws_security_group.bastion_sg.name]
  tags = {
    Name = "GoGreenBastionHost"
  }
}

# Load Balancer Configuration
resource "aws_lb" "app_lb" {
  name               = "go-green-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public.id, aws_subnet.public_b.id]
  enable_deletion_protection = false
  tags = {
    Name = "GoGreenALB"
  }
}

# Target Group Configuration
resource "aws_lb_target_group" "app_tg" {
  name     = "go-green-app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  tags = {
    Name = "GoGreenAppTargetGroup"
  }
}

# Auto Scaling Group for Web Tier
resource "aws_launch_configuration" "web_lc" {
  name          = "go-green-web-lc"
  image_id      = "ami-047d7c33f6e7b4bc4"
  instance_type = "t3.medium"
  security_groups = [aws_security_group.alb_sg.id]
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "web_asg" {
  launch_configuration = aws_launch_configuration.web_lc.id
  min_size            = 2
  max_size            = 10
  desired_capacity    = 4
  vpc_zone_identifier = [aws_subnet.public.id, aws_subnet.public_b.id]
  health_check_type        = "ELB"
  health_check_grace_period = 300
  tag {
    key                 = "Name"
    value               = "web-tier"
    propagate_at_launch = true
  }
}

# Scaling Policy for Web Tier
resource "aws_autoscaling_policy" "web_scale_up" {
  name                   = "web-scale-up"
  scaling_adjustment      = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.web_asg.name
}

resource "aws_autoscaling_policy" "web_scale_down" {
  name                   = "web-scale-down"
  scaling_adjustment      = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.web_asg.name
}

# CloudWatch Alarm for Web Tier Scaling
resource "aws_cloudwatch_metric_alarm" "web_cpu_alarm_high" {
  alarm_name          = "WebCPUAlarmHigh"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name        = "CPUUtilization"
  namespace          = "AWS/EC2"
  period             = 60
  statistic          = "Average"
  threshold          = 70
  alarm_description   = "Alarm when CPU exceeds 70%"
  alarm_actions       = [aws_autoscaling_policy.web_scale_up.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_asg.name
  }
}

resource "aws_cloudwatch_metric_alarm" "web_cpu_alarm_low" {
  alarm_name          = "WebCPUAlarmLow"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name        = "CPUUtilization"
  namespace          = "AWS/EC2"
  period             = 60
  statistic          = "Average"
  threshold          = 30
  alarm_actions       = [aws_autoscaling_policy.web_scale_down.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_asg.name
  }
}

# Auto Scaling Group for Application Tier
resource "aws_launch_configuration" "app_lc" {
  name          = "go-green-app-lc"
  image_id      = "ami-047d7c33f6e7b4bc4"
  instance_type = "t3.medium"
  security_groups = [aws_security_group.app_sg.id]
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "app_asg" {
  launch_configuration = aws_launch_configuration.app_lc.id
  min_size            = 2
  max_size            = 8
  desired_capacity    = 4
  vpc_zone_identifier = [aws_subnet.app_private.id, aws_subnet.app_private_b.id]
  health_check_type        = "EC2"
  health_check_grace_period = 300
  tag {
    key                 = "Name"
    value               = "app-tier"
    propagate_at_launch = true
  }
}

# Scaling Policy for App Tier
resource "aws_autoscaling_policy" "app_scale_up" {
  name                   = "app-scale-up"
  scaling_adjustment      = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
}

resource "aws_autoscaling_policy" "app_scale_down" {
  name                   = "app-scale-down"
  scaling_adjustment      = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
}

# CloudWatch Alarm for App Tier Scaling
resource "aws_cloudwatch_metric_alarm" "app_cpu_alarm_high" {
  alarm_name          = "AppCPUAlarmHigh"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name        = "CPUUtilization"
  namespace          = "AWS/EC2"
  period             = 60
  statistic          = "Average"
  threshold          = 70
  alarm_description   = "Alarm when CPU exceeds 70%"
  alarm_actions       = [aws_autoscaling_policy.app_scale_up.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app_asg.name
  }
}

resource "aws_cloudwatch_metric_alarm" "app_cpu_alarm_low" {
  alarm_name          = "AppCPUAlarmLow"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name        = "CPUUtilization"
  namespace          = "AWS/EC2"
  period             = 60
  statistic          = "Average"
  threshold          = 30
  alarm_actions       = [aws_autoscaling_policy.app_scale_down.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app_asg.name
  }
}

# Database Subnet Group
resource "aws_db_subnet_group" "default" {
  name       = "go-green-db-subnet-group"
  subnet_ids = [aws_subnet.db_private.id, aws_subnet.app_private_b.id]
  tags = {
    Name = "GoGreenDBSubnetGroup"
  }
}

# Database Tier Configuration
resource "aws_db_instance" "default" {
  identifier                = "go-green-db"
  engine                    = "mysql"
  instance_class            = "db.m5.large"
  allocated_storage          = 100
  storage_type              = "gp2"
  username                  = "admin" 
  password                  = "MySecurePassword!"
  db_name                   = "gogreen_db"
  vpc_security_group_ids    = [aws_security_group.db_sg.id]
  skip_final_snapshot       = false
  multi_az                  = true  # Multi-AZ deployment for high availability
  backup_retention_period    = 7
  db_subnet_group_name      = aws_db_subnet_group.default.name
  tags = {
    Name = "GoGreenDBInstance"
  }
}

# CloudWatch Alarm Configuration
resource "aws_cloudwatch_metric_alarm" "http_error_alarm" {
  alarm_name            = "HTTP400ErrorsAlarm"
  comparison_operator   = "GreaterThanThreshold"
  evaluation_periods    = 1
  metric_name          = "4XXError"
  namespace            = "AWS/ApplicationELB"
  period               = 60
  statistic            = "Sum"
  threshold            = 100
  alarm_description     = "Alarm when there are more than 100 HTTP 400 errors in a minute"
  actions_enabled        = true
  dimensions = {
    LoadBalancer = aws_lb.app_lb.arn
  }
  alarm_actions = ["arn:aws:sns:us-west-1:123456789012:your_sns_topic"]
}

# Route 53 Configuration
resource "aws_route53_zone" "main" {
  name = "yourdomain.com"  # Replace with your domain
}

resource "aws_route53_record" "alb" {
  zone_id = aws_route53_zone.main.id
  name     = "www.yourdomain.com"  # Replace with your subdomain
  type     = "A"
  alias {
    name                   = aws_lb.app_lb.dns_name
    zone_id                = aws_lb.app_lb.zone_id
    evaluate_target_health = true
  }
}

#S3 Bucket Configuration
resource "aws_s3_bucket" "static_assets" {
  bucket = "gogreen-static-assets"  # Replace with a unique bucket name
  tags = {
    Name = "GoGreenStaticAssets"
  }
}

resource "aws_s3_bucket_acl" "static_assets_acl" {
  bucket = aws_s3_bucket.static_assets.id
  acl    = "public-read"  # Change as needed for your use case
}

# S3 Bucket for Glacier
resource "aws_s3_bucket" "archival_bucket" {
 bucket = "gogreen-archive-bucket"  # Replace with a unique bucket name
  tags = {
   Name = "GoGreenArchiveBucket"
  }
}

resource "aws_s3_bucket_acl" "archival_bucket_acl" {
  bucket = aws_s3_bucket.archival_bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  bucket = aws_s3_bucket.archival_bucket.id

  rule {
    id     = "MoveToGlacier"
    status = "Enabled"

    transition {
      days          = 30  # Transition to Glacier after 30 days
      storage_class = "GLACIER"
    }

    expiration {
      days = 365  # Expire objects after 365 days
    }
  }
}
