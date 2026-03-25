# Terraform Bible — March 2026 Rewrite

This version folds in the uncovered gaps from the last two critiques: current-version guidance, removed blocks, stronger moved/import coverage, the resource vs data custom-condition nuance, and sensitive/ephemeral data handling. As of March 23, 2026, HashiCorp’s install page lists Terraform 1.14.7 as the latest release, and the upgrade guide identifies v1.14 as the current stable minor line. For study and new projects, use the current stable 1.x release unless a lab, employer, or repo explicitly pins something older.

-----

## 1) The core mental model

Think about Terraform in this order: **variables → locals → data sources → resources → outputs**. That is the cleanest way to design modules and read other people’s code, because variables define the interface, locals shape expressions, data sources read existing objects, resources manage infrastructure, and outputs publish values to callers.

A clean file layout usually mirrors that model. HashiCorp’s style guide recommends a `terraform.tf` for `required_version` and providers, a `variables.tf` for variable blocks, and a `locals.tf` for shared locals, while noting that larger codebases often split resources and data sources into logical files by concern.

-----

## 2) Variables, locals, data, resources, outputs

**Use a variable** when the caller should decide the value.

```hcl
variable "environment" {
  type        = string
  description = "Deployment environment"
}
```

**Use a local** when the module should name, normalize, or reshape a value.

```hcl
locals {
  environment = lower(trimspace(var.environment))
}
```

**Use a data source** when Terraform should read an existing object.

```hcl
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*"]
  }
}
```

**Use a resource** when Terraform should manage the object, and **an output** when callers or operators need the value.

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.al2023.id
  instance_type = "t3.micro"
}

output "instance_id" {
  value = aws_instance.web.id
}
```

Locals are helpful, but they are a style tool, not a rule of the language. HashiCorp’s style guide says to use local values sparingly, because overuse can make code harder to understand. So “alias repeated expressions in locals” is a good team convention, not a Terraform law. A practical rule is: use locals when they remove repetition or make intent clearer; skip them when they only add indirection.

-----

## 3) Sensitive data, state, and ephemeral values

`sensitive = true` is for **redaction**, not for true secret storage. HashiCorp’s docs say that sensitive variables and outputs are hidden in normal CLI output and the HCP Terraform UI, and Terraform also treats expressions derived from sensitive values as sensitive. But Terraform still stores sensitive values in state and plan files, and `terraform output -json` or `-raw` can show them in plain text.

```hcl
variable "database_password" {
  type      = string
  sensitive = true
}

output "connection_string" {
  value     = "postgresql://admin:${var.database_password}@db.example/app"
  sensitive = true
}
```

Use `sensitive = true` when you want to reduce accidental exposure in plan/apply logs and UI output. Do not assume it protects state. HashiCorp recommends treating state as sensitive data, storing it remotely where possible, encrypting it at rest, and restricting access.

If you do not want a value stored in state or plan files, use **ephemeral values**. HashiCorp documents three main mechanisms: the `ephemeral` argument on variables and child-module outputs, the `ephemeral` block, and provider-supported write-only resource arguments. Ephemeral values are omitted from state and plan files, but Terraform restricts where they can be referenced.

```hcl
variable "api_token" {
  type      = string
  sensitive = true
  ephemeral = true
}

ephemeral "random_password" "db_password" {
  length = 16
}

resource "aws_db_instance" "main" {
  # provider-specific example; only works if the resource supports write-only args
  password_wo         = ephemeral.random_password.db_password.result
  password_wo_version = 1
}
```

One important limit: you can use `ephemeral = true` on child-module outputs, but not on root-module outputs. Use it to pass temporary secrets between modules without persisting them.

-----

## 4) count vs for_each

HashiCorp’s guidance is straightforward: use `count` when resources are identical or nearly identical; use `for_each` when instances need distinct values you cannot naturally derive from an integer.

### Use count for zero-or-one creation and simple repetition

```hcl
variable "create_bastion" {
  type    = bool
  default = false
}

resource "aws_instance" "bastion" {
  count         = var.create_bastion ? 1 : 0
  ami           = data.aws_ami.al2023.id
  instance_type = "t3.micro"
}

output "bastion_private_ip" {
  value = one(aws_instance.bastion[*].private_ip)
}
```

HashiCorp documents `one()` as the clean way to turn a zero-or-one collection into either `null` or the single value, which makes it ideal for conditional resources built with count.

### Use for_each for stable, named infrastructure

```hcl
variable "servers" {
  type = map(object({
    instance_type = string
    subnet_id     = string
  }))
}

resource "aws_instance" "web" {
  for_each = var.servers

  ami           = data.aws_ami.al2023.id
  instance_type = each.value.instance_type
  subnet_id     = each.value.subnet_id

  tags = {
    Name = each.key
  }
}
```

The deeper reason teams usually prefer `for_each` for named objects is **address stability**. `count` instances are addressed by numeric index, while `for_each` instances are addressed by key. When a collection changes shape, index-based addressing is more prone to churn and accidental replacements than key-based addressing. That is an operational consequence of Terraform’s addressing model, not just a style preference.

-----

## 5) dynamic blocks and for expressions

Use a **dynamic block** only when you need to generate repeated nested blocks. HashiCorp documents `dynamic` as a nested-block generator with `for_each` and an optional iterator; it is not for ordinary arguments. Overuse makes configurations harder to read.

```hcl
resource "aws_security_group" "web" {
  name = "web-sg"

  dynamic "ingress" {
    for_each = var.ingress_rules
    iterator = rule

    content {
      from_port   = rule.value.from_port
      to_port     = rule.value.to_port
      protocol    = rule.value.protocol
      cidr_blocks = rule.value.cidr_blocks
    }
  }
}
```

Use **for expressions** when you are transforming one collection into another. HashiCorp’s docs describe them as the tool for reshaping complex values; if you need repeated nested blocks, that is when you switch to `dynamic`.

```hcl
locals {
  prod_subnets = [
    for s in var.subnets : s.id
    if s.environment == "prod"
  ]

  upper_names = {
    for k, v in var.names : k => upper(v)
  }
}
```

-----

## 6) Function playbook

These are the functions worth memorizing first because they show up constantly in production code and exam-style exercises.

### Normalize strings early

```hcl
locals {
  environment = lower(trimspace(var.environment))
  bucket_name = replace(lower(var.bucket_name), "_", "-")
}
```

Use this for environment names, tags, and provider-specific naming rules.

### Validate enums with contains()

```hcl
variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "stage", "prod"], lower(trimspace(var.environment)))
    error_message = "environment must be dev, stage, or prod."
  }
}
```

### Merge common and specific tags with merge()

```hcl
locals {
  common_tags = {
    Project     = var.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }

  instance_tags = merge(local.common_tags, {
    Name = "web-1"
    Role = "frontend"
  })
}
```

### Use lookup() for optional map keys

```hcl
locals {
  instance_type = lookup(var.instance_types, local.environment, "t3.micro")
}
```

### Use coalesce() for override-or-default behavior

```hcl
locals {
  bucket_name = coalesce(var.bucket_name, "${var.project}-${local.environment}-artifacts")
}
```

### Use try() for uncertain object shapes

HashiCorp explicitly warns that too much `try()` can make code hard to understand.

```hcl
locals {
  db_port = try(var.database.port, 5432)
}
```

### Use can() mainly inside validation rules

```hcl
variable "cidr_block" {
  type = string

  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "cidr_block must be a valid CIDR block."
  }
}
```

### Clean names with compact() and join()

```hcl
locals {
  name_parts = compact([var.project, local.environment, var.component])
  full_name  = join("-", local.name_parts)
}
```

### Flatten nested lists with flatten()

```hcl
locals {
  all_rules = flatten([
    for sg_name, sg in var.security_groups : [
      for rule in sg.rules : {
        security_group = sg_name
        from_port      = rule.from_port
        to_port        = rule.to_port
      }
    ]
  ])
}
```

### Render files with templatefile()

```hcl
locals {
  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    app_name    = var.app_name
    environment = local.environment
  })
}
```

-----

## 7) The validation ladder

Terraform supports several validation layers, and they do different jobs. HashiCorp’s validation docs describe them this way: variable validation checks parameters during planning, preconditions validate assumptions before Terraform proceeds, postconditions validate what Terraform produced, and checks validate behavior without blocking operations.

### Type constraints — the first line of defense

```hcl
variable "tags" {
  type = map(string)
}
```

### Variable validation — enforce input contracts

```hcl
variable "instance_count" {
  type = number

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 10
    error_message = "instance_count must be between 1 and 10."
  }
}
```

### Preconditions — verify assumptions before proceeding

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.al2023.id
  instance_type = "t3.micro"

  lifecycle {
    precondition {
      condition     = data.aws_ami.al2023.architecture == "x86_64"
      error_message = "Selected AMI must be x86_64."
    }
  }
}
```

### Postconditions — validate guarantees after create/read

```hcl
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*"]
  }

  lifecycle {
    postcondition {
      condition     = self.root_device_type == "ebs"
      error_message = "AMI must be EBS-backed."
    }
  }
}
```

### Check blocks — non-blocking health tests

HashiCorp is explicit that checks do not block Terraform operations when they fail; they report warnings instead.

```hcl
check "alb_returns_200" {
  data "http" "app" {
    url = "https://${aws_lb.app.dns_name}/health"
  }

  assert {
    condition     = data.http.app.status_code == 200
    error_message = "Health endpoint did not return HTTP 200."
  }
}
```

### Edge case to memorize

Do not put precondition or postcondition blocks on both a resource and a data block that represent the same object in the same configuration, because Terraform may ignore data-block changes resulting from resource changes. In practice, if a data lookup is validating a resource you create or change in the same run, prefer putting the validation on the resource itself, usually as a postcondition when that matches the intent.

### The short distinction

|Mechanism              |Question it answers                                             |
|-----------------------|----------------------------------------------------------------|
|**Variable validation**|Did the caller give me valid input?                             |
|**Precondition**       |Is my assumption true before I proceed?                         |
|**Postcondition**      |Did the object I read or create satisfy the guarantee I rely on?|
|**Check block**        |Does the broader system still look healthy?                     |

-----

## 8) Lifecycle blocks

The `lifecycle` meta-argument customizes how Terraform handles resource lifecycle behavior. Use it deliberately.

### prevent_destroy — protect critical resources

```hcl
resource "aws_s3_bucket" "logs" {
  bucket = var.bucket_name

  lifecycle {
    prevent_destroy = true
  }
}
```

### create_before_destroy — reduce replacement downtime

```hcl
resource "aws_launch_template" "app" {
  name_prefix = "app-"

  lifecycle {
    create_before_destroy = true
  }
}
```

### ignore_changes — defer to another system

```hcl
resource "aws_autoscaling_group" "app" {
  # ...

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}
```

Use `ignore_changes` only when another system is intentionally managing part of the object and you do not want Terraform to fight it. It should be a deliberate exception, not a way to silence normal drift without understanding it.

-----

## 9) Refactoring without destruction: moved

Use a `moved` block when Terraform is already managing an object and you are changing its address in code. That includes renames, moving resources into modules, and switching existing singletons to `count` or `for_each`. HashiCorp’s refactoring docs recommend `moved` because the change is visible in code and in normal plan/apply flow.

### Rename a resource

```hcl
moved {
  from = aws_instance.app
  to   = aws_instance.web
}
```

### Move a resource into a module

```hcl
moved {
  from = aws_instance.web
  to   = module.compute.aws_instance.web
}
```

### Map an old singleton into a keyed instance when enabling for_each

```hcl
moved {
  from = aws_instance.web
  to   = aws_instance.web["primary"]
}
```

For long-lived or shared modules, keep historical `moved` blocks unless you are intentionally breaking upgrade paths. HashiCorp says removing them can be safe in private contexts when you are sure all users have already applied the migration, but otherwise you should proceed cautiously. They also recommend chaining `moved` blocks if the same object moves more than once.

-----

## 10) Importing existing infrastructure: import

Use an `import` block when the infrastructure already exists and you want to adopt it declaratively through normal plan/apply. HashiCorp’s import block reference says an import block supports `to`, plus either `id` or `identity`, and can also use `for_each` and `provider`.

### Simple import

```hcl
resource "aws_s3_bucket" "logs" {
  bucket = "my-existing-logs-bucket"
}

import {
  to = aws_s3_bucket.logs
  id = "my-existing-logs-bucket"
}
```

### Bulk import with for_each

```hcl
locals {
  buckets = {
    staging = "bucket1"
    prod    = "bucket2"
  }
}

resource "aws_s3_bucket" "this" {
  for_each = local.buckets
}

import {
  for_each = local.buckets
  to       = aws_s3_bucket.this[each.key]
  id       = each.value
}
```

### Alternate provider alias during import

```hcl
import {
  id       = "i-096fba6d03d36d262"
  to       = aws_instance.web
  provider = aws.east
}
```

Use `identity` when the provider identifies a resource by an object rather than a single string ID. You cannot use `id` and `identity` in the same import block.

-----

## 11) Stop managing without destroying: removed

`removed` is the missing fourth state-management tool many guides skip. HashiCorp documents it as the configuration-driven way to remove a resource from state, and with `lifecycle { destroy = false }` you stop managing the real infrastructure without destroying it.

```hcl
removed {
  from = aws_instance.legacy

  lifecycle {
    destroy = false
  }
}
```

This is what you use when a resource should keep existing but Terraform should no longer own its lifecycle. HashiCorp recommends `removed` over `terraform state rm` because it goes through the normal plan/apply workflow and is therefore safer and reviewable.

-----

## 12) moved vs import vs removed vs state commands

|Tool                       |Use when…                                                                                |
|---------------------------|-----------------------------------------------------------------------------------------|
|**moved**                  |Terraform already manages the object and the code address changed                        |
|**import**                 |The object exists but Terraform does not manage it yet                                   |
|**removed**                |Terraform currently manages the object and should stop, without necessarily destroying it|
|**terraform state mv / rm**|Direct state surgery for one-off operational fixes rather than code-driven migrations    |

HashiCorp’s docs explicitly position `import` and `removed` as safer, reviewable configuration-driven workflows.

-----

## 13) Day-to-day command workflow

`terraform fmt` enforces the canonical style conventions. `terraform validate` checks configuration files for syntactic and internal consistency, but it does not validate provider APIs or remote services. HashiCorp recommends running `fmt` and `validate` before committing.

A good loop is:

```bash
terraform fmt
terraform validate
terraform plan
```

Use `terraform console` to practice expressions and collection shaping. It is one of the fastest ways to build muscle memory for functions and for expressions.

### Useful drills

```
> lower(trimspace(" PROD "))
> merge({a="1"}, {b="2"}, {a="3"})
> flatten([[1,2], [], [3]])
> one(["hello"])
> lookup({dev="t3.micro"}, "prod", "t3.small")
> { for k, v in {a=1, b=2} : k => v * 2 }
> [for s in ["dev", "prod", "qa"] : upper(s) if s != "qa"]
```

`terraform test` is a different tool from `terraform validate`. HashiCorp describes tests as a way to validate module behavior and catch breaking changes using test-specific short-lived resources, while validations, preconditions, postconditions, and checks are runtime assertions about infrastructure and configuration correctness.

-----

## 14) Provider versions and the lock file

Terraform writes provider selections to `.terraform.lock.hcl` during `terraform init`, and HashiCorp recommends committing that file to version control so teams and remote runners use consistent provider versions. If you want newer matching versions, use `terraform init -upgrade`.

For production and team work, pin compatible provider versions in configuration and commit the lock file. That combination prevents “works on my machine” version drift.

-----

## 15) A clean production module pattern

```hcl
terraform {
  required_version = ">= 1.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

variable "project" {
  type = string
}

variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "stage", "prod"], lower(trimspace(var.environment)))
    error_message = "environment must be dev, stage, or prod."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}

locals {
  environment = lower(trimspace(var.environment))

  common_tags = merge(var.tags, {
    Project     = var.project
    Environment = local.environment
    ManagedBy   = "terraform"
  })
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*"]
  }

  lifecycle {
    postcondition {
      condition     = self.root_device_type == "ebs"
      error_message = "AMI must be EBS-backed."
    }
  }
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.al2023.id
  instance_type = "t3.micro"

  tags = merge(local.common_tags, {
    Name = "${var.project}-${local.environment}-web"
  })

  lifecycle {
    precondition {
      condition     = data.aws_ami.al2023.architecture == "x86_64"
      error_message = "AMI must be x86_64."
    }
  }
}

check "instance_looks_expected" {
  assert {
    condition     = aws_instance.web.instance_type == "t3.micro"
    error_message = "Instance type drifted from expected value."
  }
}

output "instance_id" {
  value = aws_instance.web.id
}
```

This pattern gives you typed inputs, input validation, normalized locals, merged tags, custom conditions, and a non-blocking check. Every part of it maps cleanly to the Terraform language features documented by HashiCorp.

-----

## 16) The short rules to memorize

Variables are the module interface. Locals are for naming and shaping expressions, not hiding everything. Use `count` for zero-or-one or nearly identical instances; use `for_each` for stable keyed infrastructure. Use `dynamic` only for repeated nested blocks. Normalize inputs early. Use `merge()` for tag overlays, `lookup()` for optional map keys, `coalesce()` for defaults, `try()` for uncertain nested fields, and `can()` mainly in validation. Use variable validation for input contracts, preconditions for assumptions, postconditions for guarantees, and checks for non-blocking health validation. Use `moved` for refactors, `import` for adoption, `removed` for giving up management, and state commands for direct state surgery. Protect secrets by understanding that `sensitive` redacts output but does not secure state; use ephemeral values when a value should not be persisted at all. Commit `.terraform.lock.hcl`, and run `fmt`, `validate`, and `plan` constantly.

# Iteration Reference

## Referencing count vs for_each Resources

### `count` resources
```hcl
aws_instance.this[*].id          # list of all IDs (splat)
aws_instance.this[0].id          # single ID by index
aws_instance.this[count.index]   # current index inside resource
```

### `for_each` resources
```hcl
{ for k, v in aws_instance.this : k => v.id }  # map of all IDs
aws_instance.this["web"].id                     # single ID by key
each.key / each.value                           # current item inside resource
```

---

## Iteration Decision Tree

### What are you iterating?

**list/tuple**
- need list output → `[ for v in x : v.attr ]`
- need map output → `{ for v in x : v.key_attr => v.val_attr }`
- need filtered list → `[ for v in x : v.attr if condition ]`

**map/object**
- need list output → `[ for k, v in x : k ]` or `[ for k, v in x : v.attr ]`
- need map output → `{ for k, v in x : k => v.attr }`
- need filtered map → `{ for k, v in x : k => v if condition }`
- need grouped map → two-step: unique keys + inner filter

---

## What Resource Meta-Argument?

| Use Case | Pattern |
|----------|---------|
| on/off toggle | `count = var.enabled ? 1 : 0` |
| multiple from map/set | `for_each = var.map` or `for_each = toset(var.list)` |
| multiple from filtered | `for_each = { for k, v in x : k => v if condition }` |

---

## Referencing Results

| Resource type | Get all | Get one |
|---------------|---------|---------|
| `count` | `aws_resource.this[*].attr` | `aws_resource.this[0].attr` |
| `for_each` | `{ for k, v in aws_resource.this : k => v.attr }` | `aws_resource.this["key"].attr` |

---

## Duplicate Key Error

When two items produce the same key, add `...` after the value to group into lists:

```hcl
# Error — duplicate keys
{ for k, v in map : v.group => k }

# Fix — ellipsis groups duplicates into a list
{ for k, v in map : v.group => k... }
```

# Terraform Data Manipulation Cheat Sheet

---

## For Expression Syntax

```hcl
# List output — square brackets, no =>
[ for v in collection : v ]
[ for v in collection : v.attribute ]
[ for v in collection : v if condition ]

# Map output — curly braces, requires =>
{ for k, v in collection : k => v }
{ for k, v in collection : k => v.attribute }
{ for k, v in collection : k => v if condition }

# One variable on a map — keys discarded, values only
[ for v in map : v.attribute ]

# One variable with map output — v serves as both key and value
{ for v in list : v => "hardcoded_value" }

# Grouping with ellipsis — collect duplicate keys into lists
{ for k, v in collection : v.group_field => v.value_field... }
```

---

## Iteration Rules

```
list/tuple   → one variable:  for v in list
map/object   → two variables: for k, v in map
set          → one variable:  for v in set (no guaranteed order)

[] output → always a list, never uses =>
{} output → always a map, ALWAYS requires k => v

count resource    → [*] splat works, [0] index works
for_each resource → [*] splat FAILS, use { for k, v in resource : k => v.attr }
```

---

## Common Transformation Patterns

```hcl
# Flatten nested lists
flatten([for k, v in map : v])

# Deduplicate — preserves list type and order
distinct([for v in collection : v.attribute])

# Deduplicate — produces set, unordered
toset([for v in collection : v.attribute])

# Convert list to map keyed by attribute
{ for v in list : v.name => v }

# Filter map to subset
{ for k, v in map : k => v if v.env == "prod" }

# Filter list to subset
[ for v in list : v if condition ]

# Group by field — one step with ellipsis
{ for k, v in collection : v.group_field => v.value_field... }

# Group by field — two step (when you need to transform grouped values)
unique_groups = toset([for k, v in collection : v.group_field])
grouped       = { for g in local.unique_groups : g => [
  for k, v in collection : v.value_field if v.group_field == g
]}

# Invert a map
{ for k, v in map : v => k }

# Invert with duplicates — group keys by value
{ for k, v in map : v => k... }

# Build composite key
{ for k, v in map : "${k}-${v.env}" => v }

# Multi-step transformation pipeline
step_1 = { for k, v in source : v.env => v... }
step_2 = { for env, items in local.step_1 : env => {
  for item in items : item.tier => item.size...
}}
step_3 = { for env, tiers in local.step_2 : env => {
  for tier, sizes in tiers : tier => {
    count = length(sizes)
    sizes = sizes
  }
}}
```

---

## Key Functions

```hcl
# Safe map lookup with default
lookup(map, key, default_value)
lookup(var.instance_sizes, var.size, "t3.nano")

# Check if value exists in list/set
contains(list, value)
contains(keys(map), key)   # check map key exists

# String contains substring
strcontains(string, substring)

# Merge maps — second map wins on conflicts
merge(map1, map2)
merge(local.common_tags, { Name = var.name })

# Flatten nested lists
flatten([[1,2],[3,4]])  →  [1,2,3,4]

# Get map keys as list
keys(map)

# Get map values as list
values(map)

# Count elements
length(collection)

# Remove duplicates from list — preserves order
distinct(list)

# Type coercion
tostring(number)
tonumber(string)
toset(list)
tolist(set)
tomap(object)

# Decode external data
csvdecode(file("servers.csv"))   # → list of maps
jsondecode(file("config.json"))  # → map or list depending on JSON

# CIDR validation
can(cidrhost(var.cidr, 0))       # use in validation blocks

# String operations
split("-", "web-prod-01")        # → ["web", "prod", "01"]
split("-", "web-prod-01")[0]     # → "web"
join("-", ["web", "prod", "01"]) # → "web-prod-01"
lower(string)
upper(string)
trimspace(string)
replace(string, old, new)
```

---

## Resource Creation Patterns

```hcl
# for_each from map — named resources
resource "aws_iam_role" "this" {
  for_each = var.servers_map
  name     = each.key
}

# for_each from list — must convert to set
resource "aws_iam_role" "this" {
  for_each = toset(var.server_names)
  name     = each.key
}

# for_each from filtered collection
resource "aws_s3_bucket_versioning" "this" {
  for_each = { for k, v in var.buckets : k => v if v.versioning }
  bucket   = aws_s3_bucket.this[each.key].id
}

# count for simple repetition
resource "aws_iam_instance_profile" "this" {
  count = 3
  name  = "profile-${count.index}"
}

# count for conditional creation
resource "aws_s3_bucket" "this" {
  count  = var.create_bucket ? 1 : 0
  bucket = var.bucket_name
}

# Cross-reference related for_each resources — always use [each.key]
resource "aws_iam_instance_profile" "this" {
  for_each = var.infrastructure
  name     = "${each.key}-profile"
  role     = aws_iam_role.this[each.key].name  # ← key alignment
}
```

---

## Output Patterns

```hcl
# Map of all resource attributes — for_each resource
output "role_arns" {
  value = { for k, v in aws_iam_role.this : k => v.arn }
}

# List of all resource attributes — count resource (splat)
output "profile_names" {
  value = aws_iam_instance_profile.this[*].name
}

# Filtered output — filter using source variable
output "prod_role_arns" {
  value = { for k, v in aws_iam_role.this : k => v.arn
            if var.infrastructure[k].env == "prod" }
}

# Safe conditional output — count resource
output "bucket_id" {
  value = one(aws_s3_bucket.this[*].id)
}

# Sensitive output
output "secret" {
  value     = aws_iam_access_key.this.secret
  sensitive = true
}
```

---

## Debugging Tools

```bash
# Open terraform console
terraform console

# Check type of any expression
> type(local.servers_map)
> type(var.infrastructure)

# Test expressions instantly without running a plan
> { for k, v in var.infrastructure : v.env => k... }
> lookup(var.instance_sizes, "jumbo", "t3.nano")
> flatten([[1,2],[3,4]])
> split("-", "web-prod-01")
```

---

## Variable Type Constraints

```hcl
# Declare with list/map — Terraform evaluates as tuple/object internally
variable "names"   { type = list(string) }
variable "config"  { type = map(string) }
variable "servers" {
  type = list(object({
    name = string
    env  = string
  }))
}
variable "buckets" {
  type = map(object({
    versioning = bool
  }))
}

# Validation patterns
validation {
  condition     = contains(["dev", "stage", "prod"], var.environment)
  error_message = "Must be dev, stage, or prod."
}

validation {
  condition     = can(cidrhost(var.cidr_block, 0))
  error_message = "Must be a valid CIDR block."
}

validation {
  condition     = length(var.name) <= 32
  error_message = "Name must be 32 characters or less."
}
```

---

## Type System Quick Reference

| What you declare | What Terraform infers | Iteration |
|------------------|-----------------------|-----------|
| `list(string)` | `tuple([string,...])` | `for v in x` |
| `list(object)` | `tuple([object,...])` | `for v in x`, access `v.attr` |
| `map(string)` | `object({k: string})` | `for k, v in x` |
| `map(object)` | `object({k: object})` | `for k, v in x`, access `v.attr` |
| `set(string)` | `set(string)` | `for v in x` (unordered) |

---

## Locals Best Practice

```hcl
# Shape data in locals — never in outputs or resources directly
locals {
  # Step 1 — raw transformation
  all_members = flatten([for k, v in var.teams : v])

  # Step 2 — build on previous local
  unique_members = toset(local.all_members)

  # Step 3 — derive final value
  member_count = length(local.unique_members)
}

# Outputs just reference locals — no logic here
output "member_count" { value = local.member_count }
output "unique_members" { value = local.unique_members }
```

**Rule:** locals → where data is shaped | outputs → where data is exposed | resources → where data is consumed

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| `aws_resource.this[*].attr` on `for_each` resource | Use `{ for k, v in aws_resource.this : k => v.attr }` |
| `for_each = var.list` | Use `for_each = toset(var.list)` |
| `contains(map, key)` | Use `contains(keys(map), key)` |
| `"${single_var}"` | Use `single_var` directly — no interpolation needed |
| Duplicate key error | Add `...` after value to group: `v.field...` |
| `lookup(map, key)` crashes on missing key | Always provide default: `lookup(map, key, default)` |
| Filtering on resource attribute that doesn't exist | Filter on source variable instead: `var.infrastructure[k].env` |