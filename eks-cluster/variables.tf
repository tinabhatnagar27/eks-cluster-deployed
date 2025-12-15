variable "aws_region" { type = string }
variable "cluster_name" { type = string }
variable "cluster_version" { type = string }

variable "vpc_cidr" { type = string }
variable "azs" { type = list(string) }
variable "public_subnets" { type = list(string) }
variable "private_subnets" { type = list(string) }

variable "node_instance_type" { type = string }
variable "desired_ng1_size" { type = number }
variable "desired_ng2_size" { type = number }
variable "ssh_key_name" { type = string }

variable "my_ip_cidr" { type = string }
variable "bastion_ami_id" { type = string }
variable "bastion_key_name" { type = string }
