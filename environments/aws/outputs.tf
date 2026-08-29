output "vpc_id" {
  description = "ID of the main VPC."
  value       = aws_vpc.main.id
}

output "test_instance_id" {
  description = "ID of the test EC2 instance."
  value       = aws_instance.test.id
}

output "test_instance_public_ip" {
  description = "Public IPv4 address of the test EC2 instance."
  value       = aws_instance.test.public_ip
}

output "test_instance_private_ip" {
  description = "Private IPv4 address of the test EC2 instance."
  value       = aws_instance.test.private_ip
}
