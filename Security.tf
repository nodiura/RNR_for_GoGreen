# Security Group Module
module "security_gr" {
  source  = "app.terraform.io/Guild_of_Cloud/security_gr/aws"
  version = "1.0.1"
  vpc_id  = aws_vpc.main.id
  
  security_groups = {
    "web" = {
      description = "Security Group for Web Tier"
      ingress_rules = [
        {
          to_port     = 22
          from_port   = 22
          cidr_blocks = ["54.0.0.0/16"]
          protocol    = "tcp"
          description = "SSH ingress rule"
        },
        {
          to_port     = 80
          from_port   = 80
          cidr_blocks = [aws_instance.bastion.private_ip]
          protocol    = "tcp"
          description = "HTTP ingress rule"
        },
        {
          to_port     = 443
          from_port   = 443
          cidr_blocks = ["54.0.0.0/16"]
          protocol    = "tcp"
          description = "HTTPS ingress rule"
        }
      ],
      egress_rules = [
        {
          to_port     = 0
          from_port   = 0
          cidr_blocks = ["0.0.0.0/0"]
          protocol    = "-1"
          description = "Allow all outbound traffic"
        }
      ]
    }
  }
}

resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["54.0.0.0/16"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["54.0.0.0/16"]
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
# Security Group for Bastion Host
resource "aws_security_group" "bastion_sg" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["203.0.113.45/32"]  # Allows traffic from your desired IP only
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.prefix}-BastionSG"
  }
}
# Security Group for Web Layer
resource "aws_security_group" "web_layer_sg" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/24"]  # Allow HTTP traffic from a specific subnet
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Allow all outbound traffic
  }
  tags = {
    Name = "${var.prefix}-WebTierSG"
  }
}
# Security Group for Application Layer
resource "aws_security_group" "app_layer_sg" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port                  = 80
    to_port                    = 80
    protocol                   = "tcp"
    cidr_blocks                = ["10.0.0.0/24"]  # Allow traffic from a specific subnet, adjust as needed
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.prefix}-AppLayerSG"
  }
}
# Database Security Group
resource "aws_security_group" "db_sg" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port                  = 3306  # MySQL
    to_port                    = 3306
    protocol                   = "tcp"
    cidr_blocks                = ["10.0.0.0/24"]  # Allow traffic from specific subnets
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.prefix}-DBSG"
  }
}