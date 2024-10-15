

# Bastion Host Instance
resource "aws_instance" "bastion" {
  ami               = "ami-09b2477d43bc5d0ac"
  instance_type     = "t3.micro"
  subnet_id         = aws_subnet.public[0].id
  security_groups   = [aws_security_group.bastion_sg.id]
  tags = {
    Name = "${var.prefix}-BastionHost"
  }
}
# Launch Configuration for Web Layer Instances
resource "aws_launch_configuration" "web_layer_lc" {
  name                 = "${var.prefix}-web-layer-lc"
  image_id             = "ami-09b2477d43bc5d0ac"  # Replace with appropriate Amazon Linux AMI ID
  instance_type        = "t3.micro"
  security_groups      = [aws_security_group.web_layer_sg.id]
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
  desired_capacity      = var.desired_web_instances
  max_size              = 4
  min_size              = 1
  vpc_zone_identifier  = aws_subnet.public[*].id
  launch_configuration  = aws_launch_configuration.web_layer_lc.id
  target_group_arns     = [aws_lb_target_group.main.arn]  # Automatically register instances with the target group
  tag {
    key                 = "Name"
    value               = "${var.prefix}-WebLayer"
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
    Name = "${var.prefix}-LoadBalancer"
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
    Name = "${var.prefix}-TargetGroup"
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

# Launch Configuration for Application Layer
resource "aws_launch_configuration" "app_layer_lc" {
  name                  = "${var.prefix}-app-layer-lc"
  image_id              = "ami-09b2477d43bc5d0ac"  # Replace with appropriate Amazon Linux AMI ID
  instance_type         = "t3.micro"
  security_groups       = [aws_security_group.app_layer_sg.id]
  lifecycle {
    create_before_destroy = true
  }
}
# Auto Scaling Group for Application Layer
resource "aws_autoscaling_group" "app_layer_asg" {
  desired_capacity      = var.desired_app_instances
  max_size              = 4
  min_size              = 1
  vpc_zone_identifier  = aws_subnet.private[*].id
  launch_configuration  = aws_launch_configuration.app_layer_lc.id
  tag {
    key                 = "Name"
    value               = "${var.prefix}-AppLayer"
    propagate_at_launch = true
  }
}

# Database Instance Configuration
resource "aws_db_instance" "default" {
  identifier                = "${lower(var.prefix)}-db"  # Ensure it's in lowercase
  engine                    = "mysql"
  engine_version            = "8.0"
  instance_class            = "db.t3.small"
  allocated_storage          = 100
  storage_type              = "gp2"
  username                  = "admin"
  password                  = random_password.db_password.result  # Use Secrets Manager in production
  db_name                   = "${lower(var.prefix)}_db"    # Make sure db_name is also compliant
  vpc_security_group_ids    = [aws_security_group.db_sg.id]
  skip_final_snapshot       = false
  final_snapshot_identifier = "${lower(var.prefix)}-final-snapshot-${var.environment}"
  multi_az                  = true
  backup_retention_period   = 14
  db_subnet_group_name      = aws_db_subnet_group.default.name
  
  tags = {
    Name        = "${lower(var.prefix)}-DBInstance"  # Ensure tags are also in lowercase
    Environment = var.environment
  }
}
# Elastic IP for Each Instance
resource "aws_eip" "web_instance_ip" {
  count   = var.desired_web_instances
  domain  = "vpc"
}
# EIP Association for EC2 instances launched in Auto Scaling Group
resource "aws_eip_association" "web_instance_eip_association" {
  count         = var.desired_web_instances
  instance_id   = element(aws_instance.web.*.id, count.index)
  allocation_id = aws_eip.web_instance_ip[count.index].id
}
# Assuming the `aws_instance` resource is created to track web server instances:
resource "aws_instance" "web" {
  count             = var.desired_web_instances
  ami               = aws_launch_configuration.web_layer_lc.image_id
  instance_type     = aws_launch_configuration.web_layer_lc.instance_type
  subnet_id         = aws_subnet.public[count.index].id
  security_groups   = [aws_security_group.web_layer_sg.id]
  tags = {
    Name = "${var.prefix}-web-instance-${count.index + 1}"
  }
}