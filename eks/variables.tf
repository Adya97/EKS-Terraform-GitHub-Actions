variable "aws_region" {}
variable "env" {}
variable "cluster_name" {}
variable "vpc_cidr_block" {}
variable "vpc_name" {}
variable "igw_name" {}

variable "pub_subnet_count" { type = number }
variable "pub_cidr_blocks"  { type = list(string) }
variable "pub_sub_name" {}

variable "pri_subnet_count" { type = number }
variable "pri_cidr_blocks"  { type = list(string) }
variable "pri_sub_name" {}

variable "public_rt_name" {}
variable "private_rt_name" {}
variable "eip_name" {}
variable "ngw_name" {}
variable "eks_sg" {}

# EKS
variable "is_eks_cluster_enabled" { type = bool }
variable "cluster_version" {}
variable "endpoint_private_access" { type = bool }
variable "endpoint_public_access"  { type = bool }

variable "ondemand_instance_types" { type = list(string) }
variable "spot_instance_types"     { type = list(string) }

variable "desired_capacity_on_demand" { type = number }
variable "min_capacity_on_demand"     { type = number }
variable "max_capacity_on_demand"     { type = number }
variable "desired_capacity_spot"      { type = number }
variable "min_capacity_spot"          { type = number }
variable "max_capacity_spot"          { type = number }

variable "addons" {
  type = list(object({
    name    = string
    version = string
  }))
}
