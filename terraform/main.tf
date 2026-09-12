module "vpc" {
  source          = "./modules/vpc"
  
  env_prefix      = var.env_prefix
  vpc_cidr_block  = var.vpc_cidr_block
  azs             = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets
}

module "eks" {
  source            = "./modules/eks"
  
  env_prefix        = var.env_prefix
  cluster_version   = var.cluster_version
  vpc_id            = module.vpc.vpc_id
  private_subnets   = module.vpc.private_subnets
  instance_types    = var.instance_types
  node_min_size     = var.node_min_size
  node_max_size     = var.node_max_size
  node_desired_size = var.node_desired_size
}