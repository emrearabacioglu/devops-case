env_prefix        = "dev"
vpc_cidr_block    = "10.0.0.0/16"
azs               = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
private_subnets   = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnets    = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

cluster_version   = "1.33"
instance_types    = ["t3.medium"]
node_min_size     = 1
node_max_size     = 3
node_desired_size = 2