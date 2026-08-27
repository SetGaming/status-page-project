output "vpc_id" {
  description = "Status Page VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "availability_zones" {
  description = "Availability zones used by the project"
  value = [
    for subnet in aws_subnet.public :
    subnet.availability_zone
  ]
}
