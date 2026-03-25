output "instance_id" {
  value = { for k, v in aws_instance.this : k => v.id }
}

output "role_arn" {
  value = { for k, v in aws_iam_role.this : k => v.arn }
}

output "ami_id" {
  value = data.aws_ami.al2023.id
}