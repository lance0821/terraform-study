resource "aws_iam_role" "this" {
  name               = "${var.name}-ec2-base-access-role"
  assume_role_policy = data.aws_iam_policy_document.trust_policy.json
}

resource "aws_iam_role_policy" "base_permissions" {
  name   = "${var.name}-access-policy"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.base_permissions.json
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name}-ec2-base-access-profile"
  role = aws_iam_role.this.name
}

resource "aws_instance" "this" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.this.name
}