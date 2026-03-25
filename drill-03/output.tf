output "instance_ids" {
    value = {
        "web" = module.web.instance_id
        "api" = module.api.instance_id
        
    }
}