resource "aws_iam_role" "this" {
  name          = "${var.name}-ec2-s3-access-role"
  assume_role_policy = data.aws_iam_policy_document.trust_policy.json
}

resource "aws_iam_role_policy" "s3_access" {
  name   = "${var.name}-s3-access-policy"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.s3_access.json
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name}-ec2-s3-access-profile"
  role = aws_iam_role.this.name
}

resource "aws_instance" "this" {
  ami                  = data.aws_ami.al2023.id
  instance_type        = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.this.name
}