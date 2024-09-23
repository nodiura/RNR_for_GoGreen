

# main.tf
provider "aws" {
  region = "us-west-1" # Specify your AWS region
}
# Create VPC
resource "aws_vpc" "gogreen_vpc" {
  cidr_block             = "10.0.0.0/16"
  enable_dns_support     = true
  enable_dns_hostnames   = true
  tags = {
    Name = "GoGreen-VPC"
  }
}
# Create Public Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.gogreen_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-west-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "Public-Subnet"
  }
}
# Create Private Subnet for Application
resource "aws_subnet" "app_private_subnet" {
  vpc_id            = aws_vpc.gogreen_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-west-1a"
  tags = {
    Name = "App-Private-Subnet"
  }
}
# Create Private Subnet for Database
resource "aws_subnet" "db_private_subnet" {
  vpc_id            = aws_vpc.gogreen_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-west-1a"
  tags = {
    Name = "DB-Private-Subnet"
  }
}
# Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.gogreen_vpc.id
  tags = {
    Name = "GoGreen-IGW"
  }
}
# Public Route Table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.gogreen_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "Public-Route-Table"
  }
}
# Associate Public Subnet with Route Table
resource "aws_route_table_association" "public_route_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}
# Create NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"  # Updated from vpc = true to domain = "vpc"
}
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat.id
  subnet_id    = aws_subnet.public_subnet.id
  tags = {
    Name = "GoGreen-NAT-Gateway"
  }
}
# Private Route Table for Application and Database Subnets
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.gogreen_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }
  tags = {
    Name = "Private-Route-Table"
  }
}
# Associate Private Subnets with Route Table
resource "aws_route_table_association" "app_private_route_assoc" {
  subnet_id      = aws_subnet.app_private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}
resource "aws_route_table_association" "db_private_route_assoc" {
  subnet_id      = aws_subnet.db_private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}
# Security Group for Web Tier
resource "aws_security_group" "web_sg" {
  vpc_id = aws_vpc.gogreen_vpc.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow HTTP traffic from anywhere
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow HTTPS traffic from anywhere
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # Allow all outbound traffic
  }
  tags = {
    Name = "Web-Tier-SG"
  }
}
# Security Group for Application Tier
resource "aws_security_group" "app_sg" {
  vpc_id = aws_vpc.gogreen_vpc.id
  ingress {
    from_port                = 8080
    to_port                  = 8080
    protocol                 = "tcp"
    security_groups          = [aws_security_group.web_sg.id]  # Reference Web SG for access
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # Allow all outbound traffic
  }
  tags = {
    Name = "App-Tier-SG"
  }
}
# Security Group for Database Tier
resource "aws_security_group" "db_sg" {
  vpc_id = aws_vpc.gogreen_vpc.id
  ingress {
    from_port                = 3306
    to_port                  = 3306
    protocol                 = "tcp"
    security_groups          = [aws_security_group.app_sg.id]  # Reference App SG for access
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # Allow all outbound traffic
  }
  tags = {
    Name = "DB-Tier-SG"
  }
}