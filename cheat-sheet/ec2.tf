resource "aws_instance" "this" {
    for_each = var.environments
  ami                  = data.aws_ami.al2023.id
  instance_type        = "t3.nano"
  iam_instance_profile = aws_iam_instance_profile.this[each.key].name
}