############################
# Inputs (rename if needed)
############################
# variable "cluster_name"       { type = string }
# variable "cidr_block"         { type = string }              # e.g., "10.0.0.0/16"
# variable "vpc_name"           { type = string }
# variable "env"                { type = string }
# variable "igw_name"           { type = string }
# variable "pub_subnet_count"   { type = number }              # e.g., 3
# variable "pub_cidr_blocks"    { type = list(string) }        # length == pub_subnet_count
# variable "pub_sub_name"       { type = string }
# variable "pri_subnet_count"   { type = number }              # e.g., 3
# variable "pri_cidr_blocks"    { type = list(string) }        # length == pri_subnet_count
# variable "pri_sub_name"       { type = string }
# variable "public_rt_name"     { type = string }
# variable "eip_name"           { type = string }
# variable "ngw_name"           { type = string }
# variable "private_rt_name"    { type = string }
# variable "eks_sg"             { type = string }

locals {
  cluster_name = var.cluster_name
}

########################################
# Discover AZs (use AZ IDs, not letters)
########################################
data "aws_availability_zones" "this" {
  state = "available"
}

# Choose how many AZs you want for public/private
locals {
  # Ensure we don't request more subnets than available AZs
  az_ids_all      = data.aws_availability_zones.this.zone_ids
  az_ids_public   = slice(local.az_ids_all, 0, min(var.pub_subnet_count, length(local.az_ids_all)))
  az_ids_private  = slice(local.az_ids_all, 0, min(var.pri_subnet_count, length(local.az_ids_all)))
}

################
# VPC & Gateway
################
resource "aws_vpc" "vpc" {
  cidr_block           = var.cidr_block
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = var.vpc_name
    Env  = var.env
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name                                          = var.igw_name
    Env                                           = var.env
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  }
}

###############
# Public subnets
###############
resource "aws_subnet" "public" {
  count                 = length(local.az_ids_public)
  vpc_id                = aws_vpc.vpc.id
  cidr_block            = var.pub_cidr_blocks[count.index]
  availability_zone_id  = local.az_ids_public[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                          = "${var.pub_sub_name}-${count.index + 1}"
    Env                                           = var.env
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
    "kubernetes.io/role/elb"                      = "1"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = var.public_rt_name
    Env  = var.env
  }
}

resource "aws_route_table_association" "public" {
  for_each       = { for idx, s in aws_subnet.public : idx => s.id }
  route_table_id = aws_route_table.public.id
  subnet_id      = each.value
}

######################
# NAT + Private subnets
######################
resource "aws_eip" "ngw" {
  domain = "vpc"
  tags = { Name = var.eip_name }
}

resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.ngw.id
  subnet_id     = aws_subnet.public[0].id  # place NGW in the first public subnet
  tags = { Name = var.ngw_name }
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_subnet" "private" {
  count                  = length(local.az_ids_private)
  vpc_id                 = aws_vpc.vpc.id
  cidr_block             = var.pri_cidr_blocks[count.index]
  availability_zone_id   = local.az_ids_private[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name                                          = "${var.pri_sub_name}-${count.index + 1}"
    Env                                           = var.env
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw.id
  }
  tags = {
    Name = var.private_rt_name
    Env  = var.env
  }
}

resource "aws_route_table_association" "private" {
  for_each       = { for idx, s in aws_subnet.private : idx => s.id }
  route_table_id = aws_route_table.private.id
  subnet_id      = each.value
}

###################
# EKS Cluster SG
###################
resource "aws_security_group" "eks_cluster" {
  name        = var.eks_sg
  description = "Cluster control-plane ingress/egress"

  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # TODO: tighten to jumpbox / office CIDRs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = var.eks_sg }
}
