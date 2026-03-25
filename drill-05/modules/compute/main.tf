data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "this" {
  ami                  = data.aws_ami.al2023.id
  instance_type        = "t3.nano"
  iam_instance_profile = var.instance_profile_name

  tags = {
    Name = var.name_prefix
  }
}