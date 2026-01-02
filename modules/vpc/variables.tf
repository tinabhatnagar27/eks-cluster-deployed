variable "vpc_cidr" {
  type = string
}

variable "azs" {
  type = list(string)
}

variable "public_subnets" {
  type = list(string)
}

variable "private_subnets" {
  type = list(string)
}

# Extra vars for bastion
variable "my_ip_cidr" {
  type        = string
  description = "Your public IP in CIDR, e.g. 1.2.3.4/32"
}

variable "bastion_ami_id" {
  type        = string
  description = "AMI ID for bastion (Amazon Linux 2 in us-east-1)"
}

variable "bastion_key_name" {
  type        = string
  description = "Key pair name for bastion SSH (e.g. eks-key)"
}
