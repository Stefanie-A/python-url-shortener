output "public_ip" {
  value       = aws_instance.web_server.public_ip
  description = "The public IP address of the web server"
}

output "private-key" {
  value     = tls_private_key.key-pair.private_key_pem
  sensitive = true

}