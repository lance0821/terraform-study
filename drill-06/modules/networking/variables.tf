variable "name" {
  type = string
}

variable "allowed_ports" {
  type    = list(number)
  default = [22, 80, 443]
}

variable "allowed_cidr" {
  type    = string
  default = "0.0.0.0/0"
  validation {
    condition     = can(cidrhost(var.allowed_cidr, 0))
    error_message = "Must be a valid CIDR block e.g. 0.0.0.0/0"
  }
}