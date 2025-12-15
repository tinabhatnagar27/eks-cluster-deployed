module "vpc" {
  source           = "./modules/vpc"
  vpc_cidr         = var.vpc_cidr
  azs              = var.azs
  public_subnets   = var.public_subnets
  private_subnets  = var.private_subnets
  bastion_ami_id   = var.bastion_ami_id
  my_ip_cidr       = var.my_ip_cidr
  bastion_key_name = var.bastion_key_name
}

module "eks" {
  source             = "./modules/eks"
  aws_region         = var.aws_region
  cluster_name       = var.cluster_name
  cluster_version    = var.cluster_version
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
  node_instance_type = var.node_instance_type
  desired_ng1_size   = var.desired_ng1_size
  desired_ng2_size   = var.desired_ng2_size
  ssh_key_name       = var.ssh_key_name
}


