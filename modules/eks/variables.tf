variable "aws_region" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "cluster_version" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "node_instance_type" {
  type = string
}

variable "desired_ng1_size" {
  type = number
}

variable "desired_ng2_size" {
  type = number
}

variable "ssh_key_name" {
  type = string
}

variable "create_helm" {
  type    = bool
  default = false
}