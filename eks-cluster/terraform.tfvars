aws_region      = "us-east-1"
cluster_name    = "prod-eks"
cluster_version = "1.29"

vpc_cidr        = "10.0.0.0/16"
azs             = ["us-east-1a", "us-east-1b"]
public_subnets  = ["10.0.0.0/24", "10.0.1.0/24"]
private_subnets = ["10.0.2.0/24", "10.0.3.0/24"]

node_instance_type = "t3.medium"
desired_ng1_size   = 3
desired_ng2_size   = 2
ssh_key_name       = "eks-key"

my_ip_cidr       = "0.0.0.0/0"
bastion_ami_id   = "ami-0e001c9271cf7f3b9"
bastion_key_name = "eks-key"
