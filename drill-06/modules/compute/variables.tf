variable "name_prefix" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.nano"
  validation {
    condition     = contains(["t3.nano", "t3.micro", "t3.small"], var.instance_type)
    error_message = "Must be t3.nano, t3.micro, or t3.small."
  }
}

variable "security_group_id" {
  type = string
}

variable "instance_profile_name" {
  type = string
}