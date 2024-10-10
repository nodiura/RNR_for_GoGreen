variable "desired_web_instances" {
  default = 2
}
variable "desired_app_instances" {
  default = 2
}
variable "desired_DB_instances" {
  default = 2
}
variable "prefix" {
  description = "Prefix for resource names"
  default     = "go-green"  # You can change this to your preferred prefix
}
# Security Group for Bastion Host
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
    Name = "GoGreenBastionSG"
  }
}
# Bastion Host Instance
resource "aws_instance" "bastion" {
  ami               = "ami-0c55b159cbfafe1f0"
  instance_type     = "t3.micro"
  subnet_id         = aws_subnet.public[0].id
  security_groups   = [aws_security_group.bastion_sg.id]
  tags = {
    Name = "GoGreenBastionHost"
  }
}
# Security Group for Web Layer
resource "aws_security_group" "web_layer_sg" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_instance.bastion.private_ip]  # Allow traffic only from Bastion Host
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Allow all outbound traffic
  }
  tags = {
    Name = "GoGreenWebLayerSG"
  }
}
# Launch Configuration for Web Layer Instances
resource "aws_launch_configuration" "web_layer_lc" {
  name                  = "${var.prefix}-web-layer-lc"
  image_id              = "ami-0c55b159cbfafe1f0"  # Replace with appropriate Amazon Linux AMI ID
  instance_type         = "t3.micro"
  security_groups       = [aws_security_group.web_layer_sg.id]
  user_data = <<-EOF
              #!/bin/bash -ex
              {
                # Update the system
                sudo dnf -y update
                # Install Apache and PHP
                sudo dnf -y install httpd php
                # Start and enable Apache
                sudo systemctl start httpd
                sudo systemctl enable httpd
                # Download and extract application
                cd /var/www/html
                sudo wget https://aws-tc-largeobjects.s3-us-west-2.amazonaws.com/CUR-TF-200-ACACAD/studentdownload/lab-app.tgz
                sudo tar xvfz lab-app.tgz
                sudo chown apache:root /var/www/html/rds.conf.php
              } &> /var/log/user_data.log
              EOF
  lifecycle {
    create_before_destroy = true
  }
}
# Auto Scaling Group for Web Layer
resource "aws_autoscaling_group" "web_layer_asg" {
  desired_capacity     = var.desired_web_instances
  max_size             = 4
  min_size             = 1
  vpc_zone_identifier = aws_subnet.public[*].id
  launch_configuration = aws_launch_configuration.web_layer_lc.id
  target_group_arns = [aws_lb_target_group.main.arn]  # Automatically register instances with the target group
  tag {
    key                 = "Name"
    value               = "GoGreenWebLayer"
    propagate_at_launch = true
  }
}
# Application Load Balancer
resource "aws_lb" "main" {
  name                       = "${var.prefix}-lb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups             = [aws_security_group.web_layer_sg.id]  # Ensure SG allows HTTP/HTTPS
  subnets                    = aws_subnet.public[*].id
  enable_deletion_protection = false
  tags = {
    Name = "${var.prefix}-load-balancer"
  }
}
# Target Group for the Load Balancer
resource "aws_lb_target_group" "main" {
  name     = "${var.prefix}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold  = 2
    unhealthy_threshold = 2
  }
  tags = {
    Name = "${var.prefix}-target-group"
  }
}
# ALB Listener for HTTP
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}
# Security Group for Application Layer
resource "aws_security_group" "app_layer_sg" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port                  = 80
    to_port                    = 80
    protocol                   = "tcp"
    security_groups            = [aws_security_group.web_layer_sg.id]  # Allow traffic from Web Layer
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "GoGreenAppLayerSG"
  }
}
# Launch Configuration for Application Layer Instances
resource "aws_launch_configuration" "app_layer_lc" {
  name                  = "${var.prefix}-app-layer-lc"
  image_id              = "ami-0c55b159cbfafe1f0"  # Replace with appropriate Amazon Linux AMI ID
  instance_type         = "t3.micro"
  security_groups       = [aws_security_group.app_layer_sg.id]
  lifecycle {
    create_before_destroy = true
  }
}
# Auto Scaling Group for Application Layer
resource "aws_autoscaling_group" "app_layer_asg" {
  desired_capacity     = var.desired_app_instances
  max_size             = 4
  min_size             = 1
  vpc_zone_identifier = aws_subnet.private[*].id
  launch_configuration = aws_launch_configuration.app_layer_lc.id
  tag {
    key                 = "Name"
    value               = "GoGreenAppLayer"
    propagate_at_launch = true
  }
}
# Database Security Group
resource "aws_security_group" "db_sg" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port                  = 3306  # MySQL
    to_port                    = 3306
    protocol                   = "tcp"
    security_groups            = [aws_security_group.app_layer_sg.id]  # Allow traffic from App Layer
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "GoGreenDBSG"
  }
}
# Database Instance Configuration
resource "aws_db_instance" "default" {
  identifier                = "go-green-db"
  engine                    = "mysql"
  engine_version            = "8.0"
  instance_class            = "t3.micro"
  allocated_storage          = 100
  storage_type              = "gp2"
  username                  = "admin"
  password                  = random_password.db_password.result  # Use Secrets Manager in production
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