output "web_server_public_ip" {
  description = "The public IP address of the EC2 web server"
  value       = aws_instance.web_server.public_ip
}

output "web_server_url" {
  description = "The HTTP URL to access the web server"
  value       = "http://${aws_instance.web_server.public_ip}"
}