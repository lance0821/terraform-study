locals {
  # all_members = flatten([for v in var.team_members : v])
  # unique_members = toset(local.all_members)
  # member_count = length(local.unique_members)
  # server_map = {for idx, v in var.servers: v => idx}
  # web_servers = [for v in var.servers: v if startswith(v, "web") ]
  # server_roles = {for v in var.servers: v => split("-", v)[0]}
  # resolved_sizes = {for size in var.requested_sizes : size => lookup(var.instance_sizes, size, "t3.nano")}
  # unknown_sizes = [for size in var.requested_sizes : size if !contains(keys(var.instance_sizes), size)]
  # valid_requests = [for size in var.requested_sizes : size if contains(keys(var.instance_sizes), size)]
  # servers = csvdecode(file("servers.csv"))
  # servers_map = {for v in local.servers: v.name => v}
  # tag_map = jsondecode(file("tags.json"))
  # prod_servers = [for server in local.servers : server if server.environment == "prod"]
  # unique_regions = toset([for server in local.servers : server.region])
  # servers_by_region = {for region in local.unique_regions : region => [for server in local.servers: server.name if server.region == region]}
  # server_with_tags = {for server in local.servers : server.name => merge({Name = server.name}, local.tag_map[server.environment]) }
  # prod_infra = [ for k, v in var.infrastructure : k if v.env == "prod" ]
  # duplicate_key_infra = { for k, v in var.infrastructure : v.tier => k... }
  # web_infra = { for k, v in var.infrastructure : k => v.size if v.tier == "web" }
  # distinct_infra = distinct([for k, v in var.infrastructure : v.az])
  # number_infra = length({ for k, v in var.infrastructure : k => v if v.env == "prod" })
  # infra = { for k, v in var.infrastructure : v.env => k... }
  # infra_count = {for k, v in local.infra: k => length(v)}
  # distinct_prod_infra = distinct([for k, v in var.infrastructure : v.size if v.env == "prod"])
  # az_tier_infra = { for k, v in var.infrastructure: v.az => v.tier...}
  # az_tier_infra_final = { for k, v in local.az_tier_infra : k => toset(v) }
  # infra_lg_xlg = [ for k, v in var.infrastructure : k if v.size == "large" || v.size == "xlarge"]

  env_servers    = { for k, v in var.infrastructure : v.env => v... }
  env_tier_sizes = { for env, servers in local.env_servers : env => { for server in servers : server.tier => server.size... } }
  env_tier_summary = { for env, tiers in local.env_tier_sizes : env => {
    for tier, sizes in tiers : tier => {
      count = length(sizes)
      sizes = sizes
    }
  } }

  /*
    variable "infrastructure" {
  default = {
    "web-prod-01" = { env = "prod", tier = "web",  az = "us-east-1a", size = "large"  }
    "web-prod-02" = { env = "prod", tier = "web",  az = "us-east-1b", size = "large"  }
    "api-prod-01" = { env = "prod", tier = "api",  az = "us-east-1a", size = "medium" }
    "db-prod-01"  = { env = "prod", tier = "db",   az = "us-east-1a", size = "xlarge" }
    "web-dev-01"  = { env = "dev",  tier = "web",  az = "us-east-1a", size = "small"  }
    "api-dev-01"  = { env = "dev",  tier = "api",  az = "us-east-1b", size = "small"  }
  }
}

    {
  "prod" = {
    "web"  = { count = 2, sizes = ["large", "large"] }
    "api"  = { count = 1, sizes = ["medium"] }
    "db"   = { count = 1, sizes = ["xlarge"] }
  }
  "dev" = {
    "web"  = { count = 1, sizes = ["small"] }
    "api"  = { count = 1, sizes = ["small"] }
  }
}
*/
}

output "env_infra" {
  value = local.env_tier_summary
}