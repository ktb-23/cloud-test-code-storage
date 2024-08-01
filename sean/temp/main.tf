provider "aws" {
  region = "ap-northeast-2"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "amazon_linux_2023_ami" {
  default = "ami-045f2d6eeb07ce8c0"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block = "192.169.0.0/16"

  tags = {
    Name = "main-vpc"
  }
}

# Subnet
resource "aws_subnet" "private_ec2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "192.169.1.0/24"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = false
}

resource "aws_subnet" "private_rds" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "192.169.2.0/24"
  availability_zone       = "ap-northeast-2b"
  map_public_ip_on_launch = false
}

# Security Group
resource "aws_security_group" "sg_ec2" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
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

resource "aws_security_group" "sg_rds" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["192.169.1.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "sg_vpc_link" {
  name   = "vpc-link-sg"
  vpc_id = aws_vpc.main.id

  # 인바운드 규칙: API Gateway에서 오는 HTTP(S) 트래픽을 허용
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP traffic from API Gateway"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS traffic from API Gateway"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "VPC Link Security Group"
  }
}


# EC2
resource "aws_instance" "ec2_1" {
  ami                    = var.amazon_linux_2023_ami
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_ec2.id
  vpc_security_group_ids = [aws_security_group.sg_ec2.id]

  tags = {
    Name = "ec2-instance-1"
  }
}

resource "aws_instance" "ec2_2" {
  ami                    = var.amazon_linux_2023_ami
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_ec2.id
  vpc_security_group_ids = [aws_security_group.sg_ec2.id]

  tags = {
    Name = "ec2-instance-2"
  }
}

# DB
resource "aws_db_instance" "mysql" {
  allocated_storage      = 20
  engine                 = "mysql"
  instance_class         = "db.t3.micro"
  db_name                = "mydb"
  username               = "admin"
  password               = "password"
  vpc_security_group_ids = [aws_security_group.sg_rds.id]
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  skip_final_snapshot    = true
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds_subnet_group"
  subnet_ids = [aws_subnet.private_rds.id, aws_subnet.private_ec2.id]

  tags = {
    Name = "rds Subnet Group"
  }
}

# S3
resource "aws_s3_bucket" "public_bucket" {
  bucket = "sean-test-code-public-bucket"

  tags = {
    Name = "public_bucket"
  }
}

# resource "aws_s3_bucket_acl" "public_bucket_acl" {
#   bucket = aws_s3_bucket.public_bucket.id
#   acl    = "public-read"
# }

#NLB
resource "aws_lb" "nlb" {
  name               = "sean-test-code-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = [aws_subnet.private_ec2.id]
}

resource "aws_lb_target_group" "tg" {
  name     = "sean-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

resource "aws_lb_target_group_attachment" "tga" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.ec2_1.id
  port             = 80
}

# VPC Link
resource "aws_apigatewayv2_vpc_link" "vpc_link" {
  name               = "sean-test-code-vpc-link"
  subnet_ids         = [aws_subnet.private_ec2.id]
  security_group_ids = [aws_security_group.sg_vpc_link.id]
}

# API Gateway
resource "aws_apigatewayv2_api" "http_api" {
  name          = "http-api"
  protocol_type = "HTTP"
  description   = "HTTP API for connecting to EC2 with HTTPS"
}

# HTTP API Gateway Integration
resource "aws_apigatewayv2_integration" "http_api_integration" {
  api_id             = aws_apigatewayv2_api.http_api.id
  integration_type   = "HTTP_PROXY"
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.vpc_link.id
  integration_uri    = aws_lb_target_group.tg.arn
  integration_method = "ANY"
}

# HTTP API Gateway Route
resource "aws_apigatewayv2_route" "proxy_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.http_api_integration.id}"
}

# HTTP API Gateway Stage
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}
