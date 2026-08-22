output "web_public_ip" {
  description = "Public IP of Web Tier instance"
  value       = aws_instance.web.public_ip
}

output "app_private_ip" {
  description = "Private IP of App Tier instance"
  value       = aws_instance.app.private_ip
}

output "db_endpoint" {
  description = "RDS DB connection endpoint"
  value       = aws_db_instance.db.endpoint
}

output "peering_connection_id" {
  description = "VPC Peering connection ID"
  value       = aws_vpc_peering_connection.peering.id
}

output "nat_gateway_public_ip" {
  description = "Public IP of the NAT Gateway"
  value       = aws_eip.nat_eip.public_ip
}

output "frontend_url" {
  description = "Public URL for the frontend application"
  value       = "http://${aws_instance.web.public_ip}"
}