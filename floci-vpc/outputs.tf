output "vpc_id" {
  description = "Created VPC ID."
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "Public subnet ID."
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "Private application subnet ID."
  value       = aws_subnet.private.id
}

output "database_subnet_id" {
  description = "Database subnet ID."
  value       = aws_subnet.database.id
}
