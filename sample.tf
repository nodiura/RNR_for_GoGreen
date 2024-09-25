# Provider Configuration
provider "aws" {
  region = "us-west-1"  # Specify the AWS region
}

# VPC Configuration
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "GoGreenVPC"
  }
}

# Subnet Configurations
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
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-west-1b"  # Second public subnet

  tags = {
    Name = "GoGreenPublicSubnetB"
  }
}

resource "aws_subnet" "app_private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-west-1a"

  tags = {
    Name = "GoGreenAppPrivateSubnet"
  }
}

resource "aws_subnet" "app_private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-west-1b"  # Second private subnet

  tags = {
    Name = "GoGreenAppPrivateSubnetB"
  }
}

resource "aws_subnet" "db_private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
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

resource "aws_route_table_association" "public_association" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_association_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "GoGreenNATGateway"
  }
}

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

# Security Groups Configuration
resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "GoGreenALBSecurityGroup"
  }
}

resource "aws_security_group" "app_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "GoGreenAppSecurityGroup"
  }
}

resource "aws_security_group" "db_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 3306  # Adjust for your DB type
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "GoGreenDBSecurityGroup"
  }
}

# Load Balancer Configuration
resource "aws_lb" "app_lb" {
  name               = "go-green-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public.id, aws_subnet.public_b.id]  # Use at least two subnets

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
  image_id      = "ami-047d7c33f6e7b4bc4"  # Ensure valid AMI ID
  instance_type = "t3.medium"               # Adjust instance type as needed
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
  vpc_zone_identifier = [aws_subnet.public.id, aws_subnet.public_b.id]  # Use at least two subnets

  health_check_type        = "ELB"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "web-tier"
    propagate_at_launch = true
  }
}

# Auto Scaling Group for Application Tier
resource "aws_launch_configuration" "app_lc" {
  name          = "go-green-app-lc"
  image_id      = "ami-047d7c33f6e7b4bc4"  # Ensure valid AMI ID
  instance_type = "t3.medium"               # Adjust instance type as needed
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
  vpc_zone_identifier = [aws_subnet.app_private.id, aws_subnet.app_private_b.id]  # Use at least two subnets

  health_check_type        = "EC2"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "app-tier"
    propagate_at_launch = true
  }
}

# Database Tier Configuration
resource "aws_db_instance" "default" {
  identifier                = "go-green-db"
  engine                    = "mysql"  # Update as needed
  instance_class            = "db.m5.large"  # Adjust as necessary
  allocated_storage          = 100
  storage_type              = "gp2"  # Remove IOPS specification
  username                  = "admin"
  password                  = "MySecurePassword!"  
  db_name                   = "gogreen_db"
  vpc_security_group_ids    = [aws_security_group.db_sg.id]
  skip_final_snapshot       = true
  multi_az                  = true
  backup_retention_period    = 7

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
    LoadBalancer = aws_lb.app_lb.dns_name
  }

  alarm_actions = ["arn:aws:sns:us-west-1:123456789012:your_sns_topic"]  # Replace with your SNS topic ARN
}

# Outputs
output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "app_private_subnet_id" {
  value = aws_subnet.app_private.id
}

output "db_private_subnet_id" {
  value = aws_subnet.db_private.id
}

output "alb_dns_name" {
  value = aws_lb.app_lb.dns_name
}