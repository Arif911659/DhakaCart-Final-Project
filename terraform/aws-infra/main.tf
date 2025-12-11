# Simple Kubernetes Infrastructure
# 1 Bastion (public) + 2 Masters + 3 Workers (private with NAT)

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ============================================
# VPC and Networking
# ============================================

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.cluster_name}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.cluster_name}-igw"
  }
}

# Public Subnet 1 (for Bastion and Load Balancer)
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.cluster_name}-public-subnet-1"
  }
}

# Public Subnet 2 (for Load Balancer - needs 2 AZs)
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.cluster_name}-public-subnet-2"
  }
}

# Private Subnet (for Masters and Workers)
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.cluster_name}-private-subnet"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.cluster_name}-nat-eip"
  }
}

# NAT Gateway (for private subnet internet access)
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "${var.cluster_name}-nat"
  }

  depends_on = [aws_internet_gateway.main]
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.cluster_name}-public-rt"
  }
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.cluster_name}-private-rt"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# ============================================
# Security Groups
# ============================================

# Load Balancer Security Group
resource "aws_security_group" "alb" {
  name        = "${var.cluster_name}-alb-sg"
  description = "Security group for application load balancer"
  vpc_id      = aws_vpc.main.id

  # HTTP from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from anywhere"
  }

  # HTTPS from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from anywhere"
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-alb-sg"
  }
}

# Bastion Security Group
resource "aws_security_group" "bastion" {
  name        = "${var.cluster_name}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = aws_vpc.main.id

  # SSH from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH from anywhere"
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-bastion-sg"
  }
}

# Master/Worker Security Group
resource "aws_security_group" "k8s_nodes" {
  name        = "${var.cluster_name}-k8s-nodes-sg"
  description = "Security group for Kubernetes nodes"
  vpc_id      = aws_vpc.main.id

  # SSH from bastion
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
    description     = "SSH from bastion"
  }

  # ICMP (ping) from bastion
  ingress {
    from_port       = -1
    to_port         = -1
    protocol        = "icmp"
    security_groups = [aws_security_group.bastion.id]
    description     = "ICMP ping from bastion"
  }

  # Kubernetes API Server (6443) from ALB
  ingress {
    from_port       = 6443
    to_port         = 6443
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Kubernetes API Server from ALB"
  }

  # Kubelet API (10250) from k8s nodes
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    self        = true
    description = "Kubelet API from k8s nodes"
  }

  # NodePort range from Load Balancer (30000-32767)
  ingress {
    from_port       = 30000
    to_port         = 32767
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "NodePort from ALB"
  }

  # All traffic between k8s nodes (for other Kubernetes ports)
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    description = "All traffic between k8s nodes"
  }

  # All outbound traffic (for internet via NAT)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-k8s-nodes-sg"
  }
}

# ============================================
# SSH Key Pair
# ============================================

resource "tls_private_key" "k8s_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "k8s_key" {
  key_name   = "${var.cluster_name}-key"
  public_key = tls_private_key.k8s_key.public_key_openssh
}

# Save private key locally
resource "local_file" "private_key" {
  content         = tls_private_key.k8s_key.private_key_pem
  filename        = "${path.module}/${var.cluster_name}-key.pem"
  file_permission = "0400"
}

# ============================================
# Data Sources
# ============================================

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

# ============================================
# EC2 Instances
# ============================================

# Bastion Host (Public Subnet)
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.bastion_instance_type
  key_name               = aws_key_pair.k8s_key.key_name
  subnet_id              = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  private_ip             = "10.0.1.10"

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y curl wget vim
              EOF

  tags = {
    Name = "${var.cluster_name}-bastion"
    Role = "bastion"
  }
}

# Master Nodes (Private Subnet)
resource "aws_instance" "masters" {
  count = var.master_count

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.master_instance_type
  key_name               = aws_key_pair.k8s_key.key_name
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.k8s_nodes.id]
  private_ip             = "10.0.10.1${count.index}"

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y curl wget vim apt-transport-https ca-certificates
              # K8s will be installed later
              EOF

  tags = {
    Name = "${var.cluster_name}-master-${count.index + 1}"
    Role = "master"
  }
}

# Worker Nodes (Private Subnet)
resource "aws_instance" "workers" {
  count = var.worker_count

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.worker_instance_type
  key_name               = aws_key_pair.k8s_key.key_name
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.k8s_nodes.id]
  private_ip             = "10.0.10.2${count.index}"

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y curl wget vim apt-transport-https ca-certificates
              # K8s will be installed later
              EOF

  tags = {
    Name = "${var.cluster_name}-worker-${count.index + 1}"
    Role = "worker"
  }
}

# ============================================
# Application Load Balancer
# ============================================

# Load Balancer
resource "aws_lb" "app" {
  name               = "${var.cluster_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  enable_deletion_protection = false

  tags = {
    Name = "${var.cluster_name}-alb"
  }
}

# Target Group (for Kubernetes NodePort - Frontend)
resource "aws_lb_target_group" "app" {
  name     = "${var.cluster_name}-tg"
  port     = 30080  # Kubernetes NodePort for Frontend
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  # Enable WebSocket support
  stickiness {
    enabled = false
    type    = "lb_cookie"
  }

  # Enable connection draining
  deregistration_delay = 30

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    port                = "30080"
    protocol            = "HTTP"
    matcher             = "200-399"
  }

  tags = {
    Name = "${var.cluster_name}-tg"
  }
}

# Register Worker nodes to Target Group
resource "aws_lb_target_group_attachment" "workers" {
  count = var.worker_count

  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.workers[count.index].id
  port             = 30080
}

# HTTP Listener (Port 80) - Frontend
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = "80"
  protocol          = "HTTP"

  # Frontend routes
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}


