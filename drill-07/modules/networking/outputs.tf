output "security_group_id" {
  value = aws_security_group.this.id
}

output "subnet_id" {
  value = data.aws_subnets.this.ids[0]
}