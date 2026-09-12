output "vpc_id" {
  value = module.aws_vpc.vpc_id
}

output "private_subnets" {
  value = module.aws_vpc.private_subnets
}