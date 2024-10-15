
# # Variable Declarations
# variable "environment" {
#   description = "The environment of the deployment (e.g., dev, stage, prod)"
#   type        = string
#   default     = "dev"
# }
# variable "desired_web_instances" {
#   default = 2
# }
# variable "desired_app_instances" {
#   default = 2
# }
# variable "desired_db_instances" {
#   default = 2
# }
# variable "prefix" {
#   description = "Prefix for resource names"
#   default     = "go-green"  # You can change this to your preferred prefix
# }
# # VPC Configuration
# resource "aws_vpc" "main" {
#   cidr_block = "10.0.0.0/16"
#   tags = {
#     Name        = "${var.prefix}VPC"
#     Environment = var.environment
#   }
# }
# # Subnet Configurations
# ## Public Subnets
# resource "aws_subnet" "public" {
#   count                   = 2
#   vpc_id                  = aws_vpc.main.id
#   cidr_block              = "10.0.${count.index + 1}.0/24"
#   availability_zone       = element(["us-west-1a", "us-west-1b"], count.index)
#   map_public_ip_on_launch = true
#   tags = {
#     Name = "${var.prefix}PublicSubnet${count.index + 1}"
#   }
# }
# ## Private Subnets
# resource "aws_subnet" "private" {
#   count             = 3
#   vpc_id            = aws_vpc.main.id
#   cidr_block        = "10.0.${count.index + 3}.0/24"
#   availability_zone = element(["us-west-1a", "us-west-1b"], count.index)
#   tags = {
#     Name = "${var.prefix}PrivateSubnet${count.index + 1}"
#   }
# }
# # Internet Gateway Configuration
# resource "aws_internet_gateway" "igw" {
#   vpc_id = aws_vpc.main.id
#   tags = {
#     Name = "${var.prefix}IGW"
#   }
# }
# # Route Table Configurations
# resource "aws_route_table" "public" {
#   vpc_id = aws_vpc.main.id
#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.igw.id
#   }
#   tags = {
#     Name = "${var.prefix}PublicRouteTable"
#   }
# }
# resource "aws_route_table_association" "public_association" {
#   count          = 2
#   subnet_id      = aws_subnet.public[count.index].id
#   route_table_id = aws_route_table.public.id
# }
# # Elastic IP for NAT Gateway
# resource "aws_eip" "nat_eip" {
#   domain = "vpc"
# }
# # NAT Gateway Configuration
# resource "aws_nat_gateway" "nat" {
#   allocation_id = aws_eip.nat_eip.id
#   subnet_id     = aws_subnet.public[0].id
#   tags = {
#     Name = "${var.prefix}NATGateway"
#   }
# }
# # Route Table for Private Subnets
# resource "aws_route_table" "private" {
#   vpc_id = aws_vpc.main.id
#   route {
#     cidr_block     = "0.0.0.0/0"
#     nat_gateway_id = aws_nat_gateway.nat.id
#   }
#   tags = {
#     Name = "${var.prefix}PrivateRouteTable"
#   }
# }
# # Route Table Associations for Private Subnets
# resource "aws_route_table_association" "private_association" {
#   count          = 3
#   subnet_id      = aws_subnet.private[count.index].id
#   route_table_id = aws_route_table.private.id
# }
# # Database Subnet Group
# resource "aws_db_subnet_group" "default" {
#   name       = "${var.prefix}-db-subnet-group"
#   subnet_ids = [aws_subnet.private[1].id, aws_subnet.private[0].id]
#   tags = {
#     Name = "${var.prefix}DBSubnetGroup"
#   }
# }
# # Security Groups
# # Security Group for Bastion Host
# resource "aws_security_group" "bastion_sg" {
#   vpc_id = aws_vpc.main.id
#   ingress {
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = ["203.0.113.45/32"]  # Replace this with your IP
#   }
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#   tags = {
#     Name = "${var.prefix}BastionSG"
#   }
# }
# # Security Group for Web Layer
# resource "aws_security_group" "web_layer_sg" {
#   vpc_id = aws_vpc.main.id
#   ingress {
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["10.0.0.0/24"]  # Allow HTTP traffic from a specific subnet
#   }
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]  # Allow all outbound traffic
#   }
#   tags = {
#     Name = "${var.prefix}WebLayerSG"
#   }
# }
# # Security Group for Application Layer
# resource "aws_security_group" "app_layer_sg" {
#   vpc_id = aws_vpc.main.id
#   ingress {
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["10.0.0.0/24"]  # Allow traffic from a specific subnet
#   }
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#   tags = {
#     Name = "${var.prefix}AppLayerSG"
#   }
# }
# # Database Security Group
# resource "aws_security_group" "db_sg" {
#   vpc_id = aws_vpc.main.id
#   ingress {
#     from_port   = 3306  # MySQL
#     to_port     = 3306
#     protocol    = "tcp"
#     cidr_blocks = ["10.0.0.0/24"]  # Allow traffic from specific subnets
#   }
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#   tags = {
#     Name = "${var.prefix}DBSG"
#   }
# }
# # Bastion Host Instance
# resource "aws_instance" "bastion" {
#   ami             = "ami-09b2477d43bc5d0ac"
#   instance_type   = "t3.micro"
#   subnet_id       = aws_subnet.public[0].id
#   security_groups = [aws_security_group.bastion_sg.id]
#   tags = {
#     Name = "${var.prefix}BastionHost"
#   }
# }
# # Launch Configuration for Web Layer Instances
# resource "aws_launch_configuration" "web_layer_lc" {
#   name                = "${var.prefix}-web-layer-lc"
#   image_id            = "ami-09b2477d43bc5d0ac"  # Replace with appropriate Amazon Linux AMI ID
#   instance_type       = "t3.micro"
#   security_groups     = [aws_security_group.web_layer_sg.id]
  
#   user_data = <<-EOF
#               #!/bin/bash -ex
#               {
#                 # Update the system
#                 sudo dnf -y update
#                 # Install Apache and PHP
#                 sudo dnf -y install httpd php
#                 # Start and enable Apache
#                 sudo systemctl start httpd
#                 sudo systemctl enable httpd
#                 # Download and extract application
#                 cd /var/www/html
#                 sudo wget https://aws-tc-largeobjects.s3-us-west-2.amazonaws.com/CUR-TF-200-ACACAD/studentdownload/lab-app.tgz
#                 sudo tar xvfz lab-app.tgz
#                 sudo chown apache:root /var/www/html/rds.conf.php
#               } &> /var/log/user_data.log
#               EOF
#   lifecycle {
#     create_before_destroy = true
#   }
# }
# # Auto Scaling Group for Web Layer
# resource "aws_autoscaling_group" "web_layer_asg" {
#   desired_capacity     = var.desired_web_instances
#   max_size             = 4
#   min_size             = 1
#   vpc_zone_identifier = aws_subnet.public[*].id
#   launch_configuration = aws_launch_configuration.web_layer_lc.id
#   target_group_arns    = [aws_lb_target_group.main.arn]  # Automatically register instances with the target group
#   tag {
#     key                 = "Name"
#     value               = "${var.prefix}WebLayer"
#     propagate_at_launch = true
#   }
# }
# # Launch Configuration for Application Layer
# resource "aws_launch_configuration" "app_layer_lc" {
#   name                  = "${var.prefix}-app-layer-lc"
#   image_id              = "ami-09b2477d43bc5d0ac"  # Replace with appropriate Amazon Linux AMI ID
#   instance_type         = "t3.micro"
#   security_groups       = [aws_security_group.app_layer_sg.id]
#   lifecycle {
#     create_before_destroy = true
#   }
# }
# # Auto Scaling Group for Application Layer
# resource "aws_autoscaling_group" "app_layer_asg" {
#   desired_capacity     = var.desired_app_instances
#   max_size             = 4
#   min_size             = 1
#   vpc_zone_identifier = aws_subnet.private[*].id
#   launch_configuration = aws_launch_configuration.app_layer_lc.id
#   tag {
#     key                 = "Name"
#     value               = "${var.prefix}AppLayer"
#     propagate_at_launch = true
#   }
# }
# # Database Instance Configuration
# resource "aws_db_instance" "default" {
#   identifier                = "go-green-db"
#   engine                    = "mysql"
#   engine_version            = "8.0"
#   instance_class            = "db.t3.small"
#   allocated_storage          = 100
#   storage_type              = "gp2"
#   username                  = "admin"
#   password                  = random_password.db_password.result  # Use Secrets Manager in production
#   db_name                   = "gogreen_db"
#   vpc_security_group_ids    = [aws_security_group.db_sg.id]
#   skip_final_snapshot       = false
#   final_snapshot_identifier = "mydb-final-snapshot-${var.environment}"
#   multi_az                  = true
#   backup_retention_period   = 14
#   db_subnet_group_name      = aws_db_subnet_group.default.name
  
#   tags = {
#     Name        = "${var.prefix}DBInstance"
#     Environment = var.environment
#   }
# }
# # Application Load Balancer
# resource "aws_lb" "main" {
#   name                       = "${var.prefix}-lb"
#   internal                   = false
#   load_balancer_type         = "application"
#   security_groups            = [aws_security_group.web_layer_sg.id]  # Ensure SG allows HTTP/HTTPS
#   subnets                    = aws_subnet.public[*].id
#   enable_deletion_protection = false
#   tags = {
#     Name = "${var.prefix}-load-balancer"
#   }
# }
# # Load Balancer Target Group
# resource "aws_lb_target_group" "main" {
#   name     = "${var.prefix}-tg"
#   port     = 80
#   protocol = "HTTP"
#   vpc_id   = aws_vpc.main.id
#   health_check {
#     path                = "/"
#     interval            = 30
#     timeout             = 5
#     healthy_threshold  = 2
#     unhealthy_threshold = 2
#   }
#   tags = {
#     Name = "${var.prefix}-target-group"
#   }
# }
# # ALB Listener for HTTP
# resource "aws_lb_listener" "http" {
#   load_balancer_arn = aws_lb.main.arn
#   port              = 80
#   protocol          = "HTTP"
  
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.main.arn
#   }
# }
# # S3 Buckets Configuration (static asset bucket removed as mentioned in the previous entry)
# resource "aws_s3_bucket" "static_assets" {
#   bucket = "${var.prefix}-static-assets"
#   tags = {
#     Name = "${var.prefix}StaticAssets"
#   }
# }
# resource "aws_s3_bucket_versioning" "static_assets_versioning" {
#   bucket = aws_s3_bucket.static_assets.id
#   versioning_configuration {
#     status = "Enabled"
#   }
# }
# resource "aws_s3_bucket" "archival_bucket" {
#   bucket = "${var.prefix}-archive-bucket"
#   tags = {
#     Name = "${var.prefix}ArchivalBucket"
#   }
# }
# resource "aws_s3_bucket_versioning" "archival_bucket_versioning" {
#   bucket = aws_s3_bucket.archival_bucket.id
#   versioning_configuration {
#     status = "Enabled"
#   }
# }
# # S3 Bucket Lifecycle Configuration
# resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
#   bucket = aws_s3_bucket.archival_bucket.id
#   rule {
#     id     = "MoveToGlacier"
#     status = "Enabled"
#     transition {
#       days          = 30
#       storage_class = "GLACIER"
#     }
#     expiration {
#       days = 365
#     }
#   }
# }
# # IAM Role for S3 Replication (needs to be defined if you're using replication)
# resource "aws_iam_role" "replication_role" {
#   name = "${var.prefix}-S3ReplicationRole"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect = "Allow",
#         Principal = {
#           Service = "s3.amazonaws.com"
#         },
#         Action = "sts:AssumeRole",
#       },
#     ],
#   })
# }
# resource "aws_iam_role_policy" "replication_policy" {
#   name = "${var.prefix}-s3-replication-policy"
#   role = aws_iam_role.replication_role.id
#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Action = [
#           "s3:GetObject",
#           "s3:ListBucket",
#           "s3:ReplicateObject",
#           "s3:ReplicateDelete",
#         ],
#         Effect = "Allow",
#         Resource = [
#           aws_s3_bucket.static_assets.arn,
#           "${aws_s3_bucket.static_assets.arn}/*", # Allows access to all objects in this bucket
#         ],
#       },
#       {
#         Action = [
#           "s3:PutObject",
#           "s3:ReplicateObject",
#           "s3:ReplicateDelete",
#         ],
#         Effect = "Allow",
#         Resource = [
#           aws_s3_bucket.archival_bucket.arn,
#           "${aws_s3_bucket.archival_bucket.arn}/*", # Allows access to all objects in the destination bucket
#         ],
#       },
#     ],
#   })
# }
# # SNS Topic
# resource "aws_sns_topic" "critical_alerts" {
#   name = "${var.prefix}-CriticalEventAlerts"
# }
# # SNS Topic Subscription (for Email)
# resource "aws_sns_topic_subscription" "critical_alerts_email" {
#   topic_arn = aws_sns_topic.critical_alerts.arn
#   protocol  = "email"
#   endpoint  = "your-email@example.com"  # Change to your email for notifications
# }
# # CloudWatch Alarms
# ## High CPU Alarm for EC2
# resource "aws_cloudwatch_metric_alarm" "high_cpu" {
#   alarm_name          = "HighCPUAlarm"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = 2
#   metric_name         = "CPUUtilization"
#   namespace           = "AWS/EC2"
#   period              = 300
#   statistic           = "Average"
#   threshold           = 80
#   alarm_actions       = [aws_sns_topic.critical_alerts.arn]
# }
# ## High DB Connections Alarm
# resource "aws_cloudwatch_metric_alarm" "high_db_connections" {
#   alarm_name          = "HighDBConnections"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = 2
#   metric_name         = "DatabaseConnections"
#   namespace           = "AWS/RDS"
#   period              = 300
#   statistic           = "Average"
#   threshold           = 100
#   dimensions = {
#     DBInstanceIdentifier = aws_db_instance.default.id
#   }
#   alarm_actions = [aws_sns_topic.critical_alerts.arn]
# }
# ## HTTP 400 Errors Alarm
# resource "aws_cloudwatch_metric_alarm" "http_error_alarm" {
#   alarm_name          = "HTTP400ErrorsAlarm"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = 1
#   metric_name         = "4XXError"
#   namespace           = "AWS/ApplicationELB"
#   period              = 60
#   statistic           = "Sum"
#   threshold           = 100
#   dimensions = {
#     LoadBalancer = aws_lb.main.arn
#   }
#   alarm_actions = [aws_sns_topic.critical_alerts.arn]
# }
# # Output SNS Topic ARN
# output "sns_topic_arn" {
#   value = aws_sns_topic.critical_alerts.arn
# }
# # Output S3 Bucket ARNs
# output "static_assets_bucket_arn" {
#   value = aws_s3_bucket.static_assets.arn
# }
# output "archival_bucket_arn" {
#   value = aws_s3_bucket.archival_bucket.arn
# }