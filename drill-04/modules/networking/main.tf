resource "aws_security_group" "this" {
  name = var.name
}

resource "aws_vpc_security_group_ingress_rule" "ingress_rules" {
  security_group_id = aws_security_group.this.id
  for_each          = toset([for p in var.allowed_ports : tostring(p)])
  ip_protocol       = "tcp"
  from_port         = tonumber(each.key)
  to_port           = tonumber(each.key)
  cidr_ipv4         = "0.0.0.0/0"

}

resource "aws_vpc_security_group_egress_rule" "egress_rules" {
  security_group_id = aws_security_group.this.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

}