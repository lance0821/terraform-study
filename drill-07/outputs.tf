output "prefix" {
    value = module.naming.prefix
}

output "instance_id" {
    value = module.compute.instance_id
}

output "security_group_id" {
    value = module.networking.security_group_id
}

output "role_arn" {
    value = module.iam.role_arn
}

output "subnet_id" {
    value = module.networking.subnet_id
}