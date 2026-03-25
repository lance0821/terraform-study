variable "team_members" {
  default = {
    "engineering" = ["alice", "bob", "carol"]
    "devops"      = ["carol", "dave"]
    "security"    = ["eve", "alice"]
  }
}

variable "servers" {
  default = ["web-01", "web-02", "api-01", "db-01"]
}

variable "instance_sizes" {
  default = {
    "small"  = "t3.nano"
    "medium" = "t3.micro"
    "large"  = "t3.small"
  }
}

variable "requested_sizes" {
  default = ["small", "medium", "xlarge", "large", "jumbo"]
}

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