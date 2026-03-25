output "instance_information" {
  value = {
    prefix      = module.naming.prefix
    instance_id = module.compute.instance_id
  }
}