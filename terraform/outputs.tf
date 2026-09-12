output "eks_cluster_name" {
  value       = module.eks.cluster_name
  description = "EKS Cluster Name for Jenkins Pipeline"
}