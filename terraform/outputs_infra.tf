output "nat_gateway_id" {
  value = aws_nat_gateway.main.id
}

output "nat_public_ip" {
  value = aws_eip.nat.public_ip
}

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "jenkins_private_ip" {
  value = aws_instance.jenkins.private_ip
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "eks_cluster_name" {
  value = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  value     = aws_eks_cluster.main.endpoint
  sensitive = true
}

output "rds_endpoint" {
  value     = aws_db_instance.postgres.endpoint
  sensitive = true
}

output "database_secret_arn" {
  value = aws_secretsmanager_secret.database.arn
}
