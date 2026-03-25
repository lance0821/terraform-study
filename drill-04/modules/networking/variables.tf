variable "name" {
    type = string
    default = "default"
    }
variable "allowed_ports" {
    type = list(number)
    default = [80, 22, 443]
}