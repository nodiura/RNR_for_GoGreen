# Provider Configuration (assuming AWS as the cloud provider)
provider "aws" {
  region = "us-east-1"
}
 
# Security Group to allow access to Apache, Tomcat, and MySQL
resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow HTTP, HTTPS, and MySQL traffic"
 
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
 
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
 
# Web Tier: Create 6 virtual machines with Apache Tomcat and PHP
resource "aws_instance" "web_tier" {
  count         = 6
  instance_type = "t2.medium" # 2 vCPUs, 4GB memory
  ami           = "ami-0abcdef1234567890" # Placeholder for Red Hat Enterprise Linux 8 AMI
  security_groups = [aws_security_group.allow_http.name]
  tags = {
    Name = "web-tier-instance-${count.index}"
  }
 
  # Install Apache Tomcat and PHP on Web Tier instances
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd tomcat php
              systemctl start httpd
              systemctl start tomcat
              systemctl enable httpd
              systemctl enable tomcat
              EOF
}
 
# Application Tier: Create 5 virtual machines for Java applications
resource "aws_instance" "app_tier" {
  count         = 5
  instance_type = "t2.xlarge" # 4 vCPUs, 16GB memory
  ami           = "ami-0abcdef1234567890" # Placeholder for Red Hat Enterprise Linux 8 AMI
  security_groups = [aws_security_group.allow_http.name]
 
  tags = {
    Name = "app-tier-instance-${count.index}"
  }
 
  # Install Java SRE 7
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y java-1.7.0-openjdk
              EOF
}
 
# Database Tier: Create 2 virtual machines for MySQL Cluster
resource "aws_instance" "db_tier" {
  count         = 2
  instance_type = "t2.2xlarge" # 8 vCPUs, 32GB memory
  ami           = "ami-0abcdef1234567890" # Placeholder for Red Hat Enterprise Linux 8 AMI
  security_groups = [aws_security_group.allow_http.name]
 
  tags = {
    Name = "db-tier-instance-${count.index}"
  }
 
  # Install MySQL on Database Tier instances
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y mysql-server
              systemctl start mysqld
              systemctl enable mysqld
              EOF
 
  root_block_device {
    volume_size = 5500 # 5.5 TB of storage
  }
}
 
# Output the Public IPs of the Web, App, and DB Tiers
output "web_tier_ips" {
  value = aws_instance.web_tier[*].public_ip
}
 
output "app_tier_ips" {
  value = aws_instance.app_tier[*].public_ip
}
 
output "db_tier_ips" {
  value = aws_instance.db_tier[*].public_ip
}