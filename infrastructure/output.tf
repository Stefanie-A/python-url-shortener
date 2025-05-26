# output "public_ip" {
#   value       = aws_instance.ec2-instance.public_ip
#   description = "The public IP address of the web server"
# }

# output "private-key" {
#   value     = tls_private_key.key-pair.private_key_pem
#   sensitive = true

# }

output "ecr_repository_url" {
  description = "The URL of the ECR repository."
  value       = aws_ecr_repository.ecr_repository.repository_url
}

output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer."
  value       = aws_lb.main_alb.dns_name
}
