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
