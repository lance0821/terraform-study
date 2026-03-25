resource "aws_security_group" "this" {
  name = var.name
}

resource "aws_vpc_security_group_ingress_rule" "ingess_rules" {
  security_group_id = aws_security_group.this.id
  for_each          = toset([for p in var.allowed_ports : tostring(p)])

  cidr_ipv4   = var.allowed_cidr
  from_port   = tonumber(each.value)
  ip_protocol = "tcp"
  to_port     = tonumber(each.value)
}
resource "aws_vpc_security_group_egress_rule" "egess_rules" {
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = var.allowed_cidr
  ip_protocol       = "-1"
}