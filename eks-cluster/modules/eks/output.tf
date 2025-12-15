output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded cluster CA data"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "node_security_group_id" {
  description = "Security group ID used by worker nodes"
  value       = aws_security_group.nodes.id
}
