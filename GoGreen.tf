
# Variable Declarations
variable "environment" {
  description = "The environment of the deployment (e.g., dev, stage, prod)"
  type        = string
  default     = "dev"
}
# VPC Configuration
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name        = "GoGreenVPC"
    Environment = var.environment
  }
}
# Subnet Configurations
## Public Subnets
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = element(["us-west-1a", "us-west-1b"], count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "GoGreenPublicSubnet${count.index == 0 ? "" : "B"}"
  }
}
## Private Subnets
resource "aws_subnet" "private" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 3}.0/24"
  availability_zone = element(["us-west-1a", "us-west-1b", "us-west-1c"], count.index)

  tags = {
    Name = "GoGreen${count.index == 1 ? "App" : count.index == 2 ? "DB" : ""}PrivateSubnet${count.index == 1 ? "B" : ""}"
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
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
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
resource "aws_route_table_association" "private_association" {
  count          = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
# Security Groups Configuration
resource "aws_security_group" "bastion_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["203.0.113.45/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "GoGreenBastionSecurityGroup"
  }
}
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
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
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
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
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
# AWS KMS Key for Encryption
resource "aws_kms_key" "s3_kms_key" {
  description = "KMS key for S3 bucket encryption"
  key_usage   = "ENCRYPT_DECRYPT"

  tags = {
    Name = "GoGreenS3KMSKey"
  }
}
# S3 Buckets Configuration
resource "aws_s3_bucket" "static_assets" {
  bucket = "gogreen-static-assets"

  tags = {
    Name = "GoGreenStaticAssets"
  }
}
resource "aws_s3_bucket_versioning" "static_assets_versioning" {
  bucket = aws_s3_bucket.static_assets.id

  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket" "archival_bucket" {
  bucket = "gogreen-archive-bucket"

  tags = {
    Name = "GoGreenArchiveBucket"
  }
}
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
# IAM Role for Lambda Execution
resource "aws_iam_role" "lambda_exec_role" {
  name = "EBSnapshotLambdaRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole",
      },
    ],
  })
}
# IAM Role for S3 Replication
resource "aws_iam_role" "replication_role" {
  name = "S3ReplicationRole"
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
resource "aws_iam_role_policy" "replication_policy" {
  name = "s3-replication-policy"
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
# Database Subnet Group
resource "aws_db_subnet_group" "default" {
  name       = "go-green-db-subnet-group"
  subnet_ids = [aws_subnet.private[1].id, aws_subnet.private[0].id]

  tags = {
    Name = "GoGreenDBSubnetGroup"
  }
}
# Database Instance Configuration
resource "aws_db_instance" "default" {
  identifier                = "go-green-db"
  engine                    = "mysql"
  engine_version            = "8.0"
  instance_class            = "db.m5.large"
  allocated_storage         = 100
  storage_type              = "gp2"
  username                  = "admin"
  password                  = "your_password_here" # Security! Consider using Secrets Manager.
  db_name                   = "gogreen_db"
  vpc_security_group_ids    = [aws_security_group.db_sg.id]
  skip_final_snapshot       = false
  final_snapshot_identifier = "mydb-final-snapshot-${var.environment}"
  multi_az                  = true
  backup_retention_period   = 14
  db_subnet_group_name      = aws_db_subnet_group.default.name

  tags = {
    Name        = "GoGreenDBInstance"
    Environment = var.environment
  }
}
# Load Balancer Configuration
resource "aws_lb" "app_lb" {
  name                       = "go-green-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb_sg.id]
  subnets                    = aws_subnet.public[*].id
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
# Bastion Host Configuration
resource "aws_instance" "bastion" {
  ami             = "ami-047d7c33f6e7b4bc4" # Use a valid AMI ID
  instance_type   = "t3.micro"
  subnet_id       = aws_subnet.public[0].id
  security_groups = [aws_security_group.bastion_sg.name]

  tags = {
    Name        = "GoGreenBastionHost"
    Environment = var.environment
  }
}
# Secrets Manager Configuration
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "db_credentials"
  description = "Database credentials for GoGreen"

  tags = {
    Name = "GoGreenDBCredentials"
  }
}
resource "random_password" "db_password" {
  length  = 16
  special = true
}
resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = "dbadmin"
    password = random_password.db_password.result
    host     = aws_db_instance.default.endpoint
  })
}
# Route 53 Configuration
resource "aws_route53_zone" "main" {
  name = "yourdomain.com" # Change to your domain
}
resource "aws_route53_record" "alb" {
  zone_id = aws_route53_zone.main.id
  name    = "www.yourdomain.com" # Change to your desired subdomain
  type    = "A"

  alias {
    name                   = aws_lb.app_lb.dns_name
    zone_id                = aws_lb.app_lb.zone_id
    evaluate_target_health = true
  }
}
# SNS Topic
resource "aws_sns_topic" "critical_alerts" {
  name = "CriticalEventAlerts"
}
# SNS Topic Subscription (for Email)
resource "aws_sns_topic_subscription" "critical_alerts_email" {
  topic_arn = aws_sns_topic.critical_alerts.arn
  protocol  = "email"
  endpoint  = "youremail@example.com" # Replace with your email
}
# CloudWatch Alarms
## High CPU Alarm for EC2
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "HighCPUAlarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"

  alarm_description = "Triggers when CPU > 80%"
  dimensions = {
    InstanceId = aws_instance.bastion.id # Reference the Bastion host
  }

  alarm_actions = [aws_sns_topic.critical_alerts.arn]
}
## High DB Connections Alarm
resource "aws_cloudwatch_metric_alarm" "high_db_connections" {
  alarm_name          = "HighDBConnections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "100"

  alarm_description = "Triggers when DB connections exceed 100."
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.default.id
  }

  alarm_actions = [aws_sns_topic.critical_alerts.arn]
}
## HTTP 400 Errors Alarm
resource "aws_cloudwatch_metric_alarm" "http_error_alarm" {
  alarm_name          = "HTTP400ErrorsAlarm"
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
# EBS Snapshot Automation Lambda Function
resource "aws_lambda_function" "ebs_snapshot_lambda" {
  function_name = "EBSnapshotAutomation"
  handler       = "index.handler"
  role          = aws_iam_role.lambda_exec_role.arn
  runtime       = "python3.8"
  filename      = "path_to_your_lambda_zip_file.zip" # Update with the actual path

  environment {
    variables = {
      INSTANCE_ID = aws_instance.b

      INSTANCE_ID = aws_instance.bastion.id
      RETENTION   = 7
    }
  }
}
# Lambda IAM Policy for EBS Snapshot
resource "aws_iam_role_policy" "lambda_policy" {
  name = "EBSnapshotLambdaPolicy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ec2:CreateSnapshot",
          "ec2:DescribeVolumes",
          "ec2:DeleteSnapshot",
          "ec2:DescribeSnapshots",
        ],
        Resource = "*",
      },
    ],
  })
}
# CloudWatch Event Rule for EBS Snapshots Scheduling
resource "aws_cloudwatch_event_rule" "ebs_snapshot_schedule" {
  name                = "ebs-snapshot-schedule"
  description         = "Scheduled rule to trigger EBS snapshot Lambda function"
  schedule_expression = "cron(0 2 * * ? *)" # Adjust to your desired schedule
}
# Permission to invoke Lambda function from CloudWatch
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ebs_snapshot_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ebs_snapshot_schedule.arn
}
# Target to invoke the Lambda function on schedule
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.ebs_snapshot_schedule.name
  target_id = "EBSnapshotLambdaFunction"
  arn       = aws_lambda_function.ebs_snapshot_lambda.arn
}