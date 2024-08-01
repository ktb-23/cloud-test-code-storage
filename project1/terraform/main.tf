provider "aws" {
  region = "ap-northeast-2"  
}

# VPC 설정
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "subnet1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-northeast-2a"
}

resource "aws_subnet" "subnet2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-northeast-2c"
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "a1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "a2" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.rt.id
}

# 보안 그룹 설정
resource "aws_security_group" "web_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
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

resource "aws_security_group" "db_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 인스턴스 설정 
resource "aws_instance" "react_server" {
  ami                    = "ami-0284d6e50a03a9e11"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.subnet1.id
  key_name               = "test"
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y docker.io
    systemctl start docker
    systemctl enable docker
    curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-\$(uname -s)-\$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
  EOF

  tags = {
    Name = "react-server"
  }
}

resource "aws_instance" "flask_server" {
  ami                    = "ami-0284d6e50a03a9e11"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.subnet2.id
  key_name               = "test"
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y docker.io
    systemctl start docker
    systemctl enable docker
    curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-\$(uname -s)-\$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
  EOF

  tags = {
    Name = "flask-server"
  }
}


# RDS 설정
resource "aws_db_instance" "main" {
  allocated_storage    = 20
  engine               = "mysql"
  engine_version       = "8.0.35"  # 유효한 MySQL 버전으로 변경
  instance_class       = "db.t3.micro"  # 인스턴스 클래스 변경
  username             = "admin"
  password             = "mypassword12^^"  # 주어진 비밀번호로 변경
  parameter_group_name = "default.mysql8.0"
  skip_final_snapshot  = true

  vpc_security_group_ids = [aws_security_group.db_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
}

resource "aws_db_subnet_group" "main" {
  name       = "main"
  subnet_ids = [
    aws_subnet.subnet1.id, 
    aws_subnet.subnet2.id]

  tags = {
    Name = "main"
  }
}

# S3 버킷 설정 (정적 파일)
resource "aws_s3_bucket" "static_site" {
  bucket = "tony-jung-first-bucket"  # 소문자와 하이픈만 사용
}

data "aws_iam_policy_document" "static_site_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.static_site.arn}/*"]
  }
}

resource "aws_s3_bucket_policy" "static_site_policy" {
  bucket = aws_s3_bucket.static_site.id
  policy = data.aws_iam_policy_document.static_site_policy.json
}

resource "aws_s3_bucket_website_configuration" "static_site" {
  bucket = aws_s3_bucket.static_site.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_object" "index" {
  bucket = aws_s3_bucket.static_site.bucket
  key    = "index.html"
  source = "index.html"
}

resource "aws_s3_object" "error" {
  bucket = aws_s3_bucket.static_site.bucket
  key    = "error.html"
  source = "error.html"
}


# API Gateway 설정
resource "aws_api_gateway_rest_api" "example" {
  name        = "example-api"
  description = "API Gateway for example.com"
}

resource "aws_api_gateway_resource" "react_resource" {
  rest_api_id = aws_api_gateway_rest_api.example.id
  parent_id   = aws_api_gateway_rest_api.example.root_resource_id
  path_part   = "react"
}

resource "aws_api_gateway_method" "react_method" {
  rest_api_id   = aws_api_gateway_rest_api.example.id
  resource_id   = aws_api_gateway_resource.react_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

#API Gateway Intergration 설정
resource "aws_api_gateway_integration" "react_integration" {
  rest_api_id             = aws_api_gateway_rest_api.example.id
  resource_id             = aws_api_gateway_resource.react_resource.id
  http_method             = aws_api_gateway_method.react_method.http_method
  integration_http_method = "GET"
  type                    = "HTTP"
  uri                     = "http://${aws_instance.react_server.public_ip}:3000"
  depends_on              = [aws_instance.react_server]
}

resource "aws_api_gateway_deployment" "react_deployment" {
  rest_api_id = aws_api_gateway_rest_api.example.id
  stage_name  = "production"
  depends_on  = [aws_api_gateway_integration.react_integration]
}

resource "aws_api_gateway_stage" "react_stage" {
  rest_api_id   = aws_api_gateway_rest_api.example.id
  stage_name    = "production"
  deployment_id = aws_api_gateway_deployment.react_deployment.id
}

resource "aws_api_gateway_resource" "flask_resource" {
  rest_api_id = aws_api_gateway_rest_api.example.id
  parent_id   = aws_api_gateway_rest_api.example.root_resource_id
  path_part   = "flask"
}

resource "aws_api_gateway_method" "flask_method" {
  rest_api_id   = aws_api_gateway_rest_api.example.id
  resource_id   = aws_api_gateway_resource.flask_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "flask_integration" {
  rest_api_id             = aws_api_gateway_rest_api.example.id
  resource_id             = aws_api_gateway_resource.flask_resource.id
  http_method             = aws_api_gateway_method.flask_method.http_method
  integration_http_method = "GET"
  type                    = "HTTP"
  uri                     = "http://${aws_instance.flask_server.public_ip}:5000"
  depends_on              = [aws_instance.flask_server]  # 인스턴스가 생성된 후 통합
}

resource "aws_api_gateway_deployment" "flask_deployment" {
  rest_api_id = aws_api_gateway_rest_api.example.id
  stage_name  = "prod"
  depends_on  = [aws_api_gateway_integration.flask_integration]
}

resource "aws_api_gateway_stage" "flask_stage" {
  rest_api_id   = aws_api_gateway_rest_api.example.id
  stage_name    = "prod"
  deployment_id = aws_api_gateway_deployment.flask_deployment.id
}

output "react_api_url" {
  value = "${aws_api_gateway_deployment.react_deployment.invoke_url}/react"
}

output "flask_api_url" {
  value = "${aws_api_gateway_deployment.flask_deployment.invoke_url}/flask"
}
