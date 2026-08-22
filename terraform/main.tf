terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# --- DATA SOURCES ---
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --- VPC A: APP-VPC ---
resource "aws_vpc" "app_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "nimbuscart-app-vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "nimbuscart-public-subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.app_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "nimbuscart-app-private-subnet"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.app_vpc.id

  tags = {
    Name = "nimbuscart-igw"
  }
}

resource "aws_eip" "nat_eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "nimbuscart-nat-eip"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "nimbuscart-nat-gw"
  }
}

# --- VPC B: DATA-VPC ---
resource "aws_vpc" "data_vpc" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "nimbuscart-data-vpc"
  }
}

resource "aws_subnet" "db_subnet_1" {
  vpc_id            = aws_vpc.data_vpc.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "nimbuscart-db-subnet-1"
  }
}

resource "aws_subnet" "db_subnet_2" {
  vpc_id            = aws_vpc.data_vpc.id
  cidr_block        = "10.1.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "nimbuscart-db-subnet-2"
  }
}

resource "aws_db_subnet_group" "db_subnet_grp" {
  name       = "nimbuscart-db-subnet-group"
  subnet_ids = [aws_subnet.db_subnet_1.id, aws_subnet.db_subnet_2.id]

  tags = {
    Name = "nimbuscart-db-subnet-group"
  }
}

# --- VPC PEERING ---
resource "aws_vpc_peering_connection" "peering" {
  vpc_id        = aws_vpc.app_vpc.id
  peer_vpc_id   = aws_vpc.data_vpc.id
  auto_accept   = true

  tags = {
    Name = "app-vpc-to-data-vpc-peering"
  }
}

# --- ROUTE TABLES & ASSOCIATIONS ---
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.app_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "nimbuscart-public-rt"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.app_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  route {
    cidr_block                = "10.1.0.0/16"
    vpc_peering_connection_id = aws_vpc_peering_connection.peering.id
  }

  tags = {
    Name = "nimbuscart-private-rt"
  }
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table" "data_rt" {
  vpc_id = aws_vpc.data_vpc.id

  route {
    cidr_block                = "10.0.0.0/16"
    vpc_peering_connection_id = aws_vpc_peering_connection.peering.id
  }

  tags = {
    Name = "nimbuscart-data-rt"
  }
}

resource "aws_route_table_association" "db_assoc_1" {
  subnet_id      = aws_subnet.db_subnet_1.id
  route_table_id = aws_route_table.data_rt.id
}

resource "aws_route_table_association" "db_assoc_2" {
  subnet_id      = aws_subnet.db_subnet_2.id
  route_table_id = aws_route_table.data_rt.id
}

# --- SECURITY GROUPS ---
resource "aws_security_group" "web_sg" {
  name        = "nimbuscart-web-sg"
  description = "Allow inbound HTTP/HTTPS from Internet and SSH"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from anywhere"
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

  tags = {
    Name = "nimbuscart-web-sg"
  }
}

resource "aws_security_group" "app_sg" {
  name        = "nimbuscart-app-sg"
  description = "Allow inbound traffic from Web Tier only"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    description     = "API traffic from Web SG"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  ingress {
    description     = "SSH from Web Tier"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "nimbuscart-app-sg"
  }
}

resource "aws_security_group" "db_sg" {
  name        = "nimbuscart-db-sg"
  description = "Allow Postgres/MySQL inbound strictly from App Tier subnet"
  vpc_id      = aws_vpc.data_vpc.id

  ingress {
    description = "PostgreSQL traffic from App Tier Private Subnet"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.2.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "nimbuscart-db-sg"
  }
}

# --- DATABASE TIER ---
resource "aws_db_instance" "db" {
  identifier             = "nimbuscart-db"
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "nimbuscart"
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_grp.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = false

  tags = {
    Name = "nimbuscart-rds"
  }
}

# --- APP TIER EC2 ---
resource "aws_instance" "app" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.private_subnet.id
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  associate_public_ip_address = false
  key_name                    = var.key_name

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y docker.io python3-pip
              systemctl start docker
              systemctl enable docker

              # Run the API container passing RDS endpoint credentials
              docker run -d \
                --restart always \
                -p 5000:5000 \
                -e DB_HOST="${aws_db_instance.db.address}" \
                -e DB_PORT="5432" \
                -e DB_NAME="nimbuscart" \
                -e DB_USER="${var.db_username}" \
                -e DB_PASS="${var.db_password}" \
                ${var.api_docker_image}
              EOF

  tags = {
    Name = "nimbuscart-app-tier"
  }

  depends_on = [aws_nat_gateway.nat_gw, aws_db_instance.db]
}

# --- WEB TIER EC2 ---
resource "aws_instance" "web" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true
  key_name                    = var.key_name

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y nginx

              # Configure Nginx reverse proxy to proxy /api/ requests to App Private IP
              cat <<'NGINX_CONF' > /etc/nginx/sites-available/default
              server {
                  listen 80 default_server;
                  listen [::]:80 default_server;

                  root /var/www/html;
                  index index.html index.htm;

                  server_name _;

                  location / {
                      try_files \$uri \$uri/ =404;
                  }

                  location /api/ {
                      proxy_pass http://${aws_instance.app.private_ip}:5000/;
                      proxy_set_header Host \$host;
                      proxy_set_header X-Real-IP \$remote_addr;
                      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                  }
              }
              NGINX_CONF

              systemctl restart nginx
              EOF

  tags = {
    Name = "nimbuscart-web-tier"
  }

  depends_on = [aws_instance.app]
}