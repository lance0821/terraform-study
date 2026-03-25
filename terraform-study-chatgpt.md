# Terraform Bible

**Printable Reference — March 2026**

This version folds in the uncovered gaps from the latest critiques: current-version guidance, `removed` blocks, stronger `moved`/`import` coverage, the `resource` vs `data` custom-condition nuance, and sensitive/ephemeral data handling.

---

## Table of Contents

1. [The core mental model](#1-the-core-mental-model)
2. [Variables, locals, data, resources, outputs](#2-variables-locals-data-resources-outputs)
3. [Sensitive data, state, and ephemeral values](#3-sensitive-data-state-and-ephemeral-values)
4. [`count` vs `for_each`](#4-count-vs-for_each)
5. [`dynamic` blocks and `for` expressions](#5-dynamic-blocks-and-for-expressions)
6. [Function playbook](#6-function-playbook)
7. [The validation ladder](#7-the-validation-ladder)
8. [Lifecycle blocks](#8-lifecycle-blocks)
9. [Refactoring without destruction: `moved`](#9-refactoring-without-destruction-moved)
10. [Importing existing infrastructure: `import`](#10-importing-existing-infrastructure-import)
11. [Stop managing without destroying: `removed`](#11-stop-managing-without-destroying-removed)
12. [`moved` vs `import` vs `removed` vs state commands](#12-moved-vs-import-vs-removed-vs-state-commands)
13. [Day-to-day command workflow](#13-day-to-day-command-workflow)
14. [Provider versions and the lock file](#14-provider-versions-and-the-lock-file)
15. [A clean production module pattern](#15-a-clean-production-module-pattern)
16. [The short rules to memorize](#16-the-short-rules-to-memorize)

---

## 1) The core mental model

Think about Terraform in this order:

**variables → locals → data sources → resources → outputs**

That is the cleanest way to design modules and read other people’s code.

- **Variables** define the interface.
- **Locals** shape expressions.
- **Data sources** read existing objects.
- **Resources** manage infrastructure.
- **Outputs** publish values to callers.

A clean file layout usually mirrors that model:

- `terraform.tf` for `required_version` and providers
- `variables.tf` for variable blocks
- `locals.tf` for shared locals
- logical `.tf` files for resources and data sources by concern
- `outputs.tf` for outputs

---

## 2) Variables, locals, data, resources, outputs

Use a **variable** when the caller should decide the value.

```hcl
variable "environment" {
  type        = string
  description = "Deployment environment"
}
```

Use a **local** when the module should name, normalize, or reshape a value.

```hcl
locals {
  environment = lower(trimspace(var.environment))
}
```

Use a **data source** when Terraform should read an existing object.

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

Use a **resource** when Terraform should manage the object.

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.al2023.id
  instance_type = "t3.micro"
}
```

Use an **output** when callers or operators need the value.

```hcl
output "instance_id" {
  value = aws_instance.web.id
}
```

### Practical local-values rule

Locals are a **style tool**, not a rule of the language.

A practical rule:

- use locals when they remove repetition
- use locals when they make intent clearer
- skip them when they only add indirection

Good example:

```hcl
variable "environment" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

locals {
  environment = lower(trimspace(var.environment))

  common_tags = merge(var.tags, {
    Environment = local.environment
    ManagedBy   = "terraform"
  })
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.al2023.id
  instance_type = "t3.micro"
  tags          = local.common_tags
}
```

---

## 3) Sensitive data, state, and ephemeral values

`sensitive = true` is for **redaction**, not for true secret storage.

Use it when you want Terraform to hide values in normal CLI output and UI output.

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

### Critical rule

`sensitive = true` **does not** keep the value out of:

- state files
- plan files
- raw/json-style output commands

So the production rule is:

- use `sensitive = true` to reduce accidental display
- treat state as sensitive data
- secure remote state and access permissions properly

### Ephemeral values

If you do **not** want a value stored in state or plan files, use **ephemeral values**.

```hcl
variable "api_token" {
  type      = string
  sensitive = true
  ephemeral = true
}
```

You can also use ephemeral values in supported workflows such as write-only arguments.

```hcl
ephemeral "random_password" "db_password" {
  length = 16
}

resource "aws_db_instance" "main" {
  password_wo         = ephemeral.random_password.db_password.result
  password_wo_version = 1
}
```

### Memorize this distinction

- **Sensitive** = hide from normal output
- **Ephemeral** = do not persist in state/plan

---

## 4) `count` vs `for_each`

### Use `count` for zero-or-one or simple repetition

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

Use this for:

- optional resources
- nearly identical repeated resources
- simple numeric scaling

### Use `for_each` for stable, named infrastructure

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

Use this for:

- named instances
- keyed infrastructure
- objects with distinct settings
- safer long-term identity

### The deeper reason

`count` uses **numeric indexes**.

`for_each` uses **stable keys**.

When a collection changes shape, `count` is more likely to shift addresses and cause unintended replacement. That is the real reason `for_each` is usually preferred for named infrastructure.

### Study rule

- `count` for **0-or-1** or **N nearly identical objects**
- `for_each` for **named**, **keyed**, or **distinct** objects

---

## 5) `dynamic` blocks and `for` expressions

### `dynamic` blocks

Use a `dynamic` block only when you need to generate **repeated nested blocks**.

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

Use `dynamic` when the provider schema requires repeated nested blocks.

Do **not** use it just because you can. Literal blocks are easier to read when the structure is small and static.

### `for` expressions

Use `for` expressions to reshape collections.

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

Use them to:

- filter lists
- transform maps
- build `for_each`-friendly structures
- reshape decoded YAML/JSON/CSV input

---

## 6) Function playbook

These are the functions worth knowing cold.

### Normalize strings early

```hcl
locals {
  environment = lower(trimspace(var.environment))
  bucket_name = replace(lower(var.bucket_name), "_", "-")
}
```

Use for:

- environment names
- tags
- bucket names
- naming constraints

### Validate enums with `contains()`

```hcl
variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "stage", "prod"], lower(trimspace(var.environment)))
    error_message = "environment must be dev, stage, or prod."
  }
}
```

### Merge maps with `merge()`

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

Use for:

- tag overlays
- defaults plus overrides
- shared metadata

### Safe map access with `lookup()`

```hcl
locals {
  instance_type = lookup(var.instance_types, local.environment, "t3.micro")
}
```

### Nullable override-or-default with `coalesce()`

```hcl
locals {
  bucket_name = coalesce(var.bucket_name, "${var.project}-${local.environment}-artifacts")
}
```

### Uncertain object shape with `try()`

```hcl
locals {
  db_port = try(var.database.port, 5432)
}
```

Use `try()` when the expression may fail because the structure is uncertain.

### Validation helper with `can()`

```hcl
variable "cidr_block" {
  type = string

  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "cidr_block must be a valid CIDR block."
  }
}
```

### Clean naming with `compact()` and `join()`

```hcl
locals {
  name_parts = compact([var.project, local.environment, var.component])
  full_name  = join("-", local.name_parts)
}
```

### Flatten nested lists with `flatten()`

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

### Render files with `templatefile()`

```hcl
locals {
  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    app_name    = var.app_name
    environment = local.environment
  })
}
```

### Summary list

Memorize these first:

- `lower()`
- `trimspace()`
- `replace()`
- `contains()`
- `merge()`
- `lookup()`
- `coalesce()`
- `try()`
- `can()`
- `compact()`
- `join()`
- `flatten()`
- `one()`
- `templatefile()`

---

## 7) The validation ladder

Terraform has several validation layers, and each one solves a different problem.

### Type constraints

```hcl
variable "tags" {
  type = map(string)
}
```

Use type constraints first. They are your first line of defense.

### Variable validation

Use variable validation when the caller can pass bad input and you want a clear module contract.

```hcl
variable "instance_count" {
  type = number

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 10
    error_message = "instance_count must be between 1 and 10."
  }
}
```

### Preconditions

Use preconditions when an assumption must be true **before** Terraform proceeds.

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

### Postconditions

Use postconditions when the object Terraform read or created must satisfy a guarantee you rely on.

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

### Check blocks

Use `check` blocks for **non-blocking** health tests.

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

### The key distinction to memorize

- **Variable validation** = “Did the caller give me valid input?”
- **Preconditions** = “Is my assumption true before I proceed?”
- **Postconditions** = “Did the object satisfy the guarantee I rely on?”
- **Checks** = “Does the broader system look healthy?”

### Important nuance

If a data lookup is validating a resource you create or change in the same run, prefer putting the validation on the **resource** itself rather than duplicating conditions across both the `resource` and matching `data` block.

---

## 8) Lifecycle blocks

Use lifecycle rules deliberately, not by reflex.

### `prevent_destroy`

```hcl
resource "aws_s3_bucket" "logs" {
  bucket = var.bucket_name

  lifecycle {
    prevent_destroy = true
  }
}
```

Use for truly critical resources.

### `create_before_destroy`

```hcl
resource "aws_launch_template" "app" {
  name_prefix = "app-"

  lifecycle {
    create_before_destroy = true
  }
}
```

Use when replacement downtime matters.

### `ignore_changes`

```hcl
resource "aws_autoscaling_group" "app" {
  # ...

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}
```

Use only when another system is intentionally managing that attribute.

---

## 9) Refactoring without destruction: `moved`

Use a `moved` block when Terraform is already managing an object and you are changing its **address in code**.

That includes:

- renaming resources
- moving resources into modules
- switching a singleton to `count`
- switching a singleton to `for_each`

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

### Map an old singleton to a keyed instance

```hcl
moved {
  from = aws_instance.web
  to   = aws_instance.web["primary"]
}
```

### Production note

Keep historical `moved` blocks in long-lived or shared modules unless you intentionally want to break upgrade paths.

---

## 10) Importing existing infrastructure: `import`

Use an `import` block when infrastructure already exists and you want Terraform to adopt it declaratively.

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

### Bulk import with `for_each`

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

### Remember

`import` can use:

- `to`
- `id` or `identity`
- `for_each`
- `provider`

---

## 11) Stop managing without destroying: `removed`

Use `removed` when Terraform currently manages an object and should stop, without necessarily destroying the real infrastructure.

```hcl
removed {
  from = aws_instance.legacy

  lifecycle {
    destroy = false
  }
}
```

Use this when:

- the infrastructure should remain
- Terraform should no longer own it
- you want a code-driven, reviewable workflow

---

## 12) `moved` vs `import` vs `removed` vs state commands

Use:

- **`moved`** when Terraform already manages the object and the address changed
- **`import`** when the object exists but Terraform does not manage it yet
- **`removed`** when Terraform manages it now but should stop
- **state commands** for one-off operational state surgery

Simple memory rule:

- `moved` = refactor
- `import` = adopt
- `removed` = give up management
- `state mv` / `state rm` = direct surgery

---

## 13) Day-to-day command workflow

A good daily loop is:

```bash
terraform fmt
terraform validate
terraform plan
```

### What each one is for

- `terraform fmt` = canonical formatting
- `terraform validate` = syntax and internal consistency
- `terraform plan` = preview actual changes

### `terraform console`

Use `terraform console` to practice expressions and collection shaping.

Helpful drills:

```hcl
> lower(trimspace(" PROD "))
> merge({a="1"}, {b="2"}, {a="3"})
> flatten([[1,2], [], [3]])
> one(["hello"])
> lookup({dev="t3.micro"}, "prod", "t3.small")
> { for k, v in {a=1, b=2} : k => v * 2 }
> [for s in ["dev", "prod", "qa"] : upper(s) if s != "qa"]
```

### `terraform validate` vs `terraform test`

- `validate` checks syntax and structural correctness
- `test` checks module behavior and scenario correctness

Do not confuse them.

---

## 14) Provider versions and the lock file

Terraform writes provider selections to `.terraform.lock.hcl` during `terraform init`.

### Production habit

- pin compatible provider versions
- commit `.terraform.lock.hcl`
- use `terraform init -upgrade` intentionally

This prevents version drift across developers, CI, and remote runners.

---

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

This gives you:

- typed inputs
- input validation
- normalized locals
- shared tag strategy
- postconditions and preconditions
- non-blocking checks
- clean outputs

---

## 16) The short rules to memorize

- Variables are the module interface.
- Locals are for naming and shaping expressions, not hiding everything.
- Use `count` for zero-or-one or nearly identical instances.
- Use `for_each` for stable keyed infrastructure.
- Use `dynamic` only for repeated nested blocks.
- Normalize inputs early.
- Use `merge()` for tags.
- Use `lookup()` for optional map keys.
- Use `coalesce()` for defaults.
- Use `try()` for uncertain nested fields.
- Use `can()` mainly in validation.
- Use variable validation for input contracts.
- Use preconditions for assumptions.
- Use postconditions for guarantees.
- Use checks for non-blocking health validation.
- Use `moved` for refactors.
- Use `import` for adoption.
- Use `removed` for giving up management.
- Use state commands for direct state surgery.
- `sensitive` hides output but does not secure state.
- `ephemeral` avoids persisting the value.
- Commit `.terraform.lock.hcl`.
- Run `fmt`, `validate`, and `plan` constantly.

---

## Print Notes

For clean printing:

- use a markdown viewer that supports heading-based navigation
- export to PDF from your editor if needed
- keep code blocks wrapped and page width moderate


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


# IAM Chain Reference

## The 5 Resources — Always in This Order

```
1. data "aws_iam_policy_document" "trust"       → WHO can assume the role
2. data "aws_iam_policy_document" "permissions"  → WHAT the role can do
3. resource "aws_iam_role"                       → THE role itself
4. resource "aws_iam_role_policy"                → ATTACHES permissions to role
5. resource "aws_iam_instance_profile"           → EC2 WRAPPER for the role
```

---

## The 4 Critical Connections

```hcl
# 1. Role gets the TRUST policy — controls who can assume it
resource "aws_iam_role" "this" {
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

# 2. Role policy gets PERMISSIONS — controls what it can do
# 3. Role policy references role by .id — internal AWS relationship
resource "aws_iam_role_policy" "this" {
  role   = aws_iam_role.this.id       # ← .id not .name or .arn
  policy = data.aws_iam_policy_document.permissions.json
}

# 4. Instance profile references role by .name — EC2 needs the name
resource "aws_iam_instance_profile" "this" {
  role = aws_iam_role.this.name       # ← .name not .id or .arn
}
```

---

## Memory Hook

```
role_policy  → .id    (internal AWS relationship)
profile      → .name  (EC2 sees it externally by name)
```

---

## Complete Skeleton

```hcl
data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "permissions" {
  statement {
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = ["arn:aws:s3:::my-bucket/*"]
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.name}-role"
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

resource "aws_iam_role_policy" "this" {
  name   = "${var.name}-policy"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.permissions.json
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name}-profile"
  role = aws_iam_role.this.name
}

resource "aws_instance" "this" {
  ami                  = data.aws_ami.al2023.id
  instance_type        = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.this.name  # ← profile .name
}
```

---

## Service Principals

| Service | Principal |
|---------|-----------|
| EC2 | `ec2.amazonaws.com` |
| Lambda | `lambda.amazonaws.com` |
| ECS Task | `ecs-tasks.amazonaws.com` |
| RDS | `rds.amazonaws.com` |
| SSM | `ssm.amazonaws.com` |

---

## Inline vs Managed Policy

```hcl
# Inline — permissions specific to one role
resource "aws_iam_role_policy" "this" {
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.permissions.json
}

# Managed — reusable across multiple roles
resource "aws_iam_policy" "this" {
  policy = data.aws_iam_policy_document.permissions.json
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name    # ← .name not .id
  policy_arn = aws_iam_policy.this.arn
}

# AWS Managed Policy — attach existing AWS policy directly
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
```

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| `role = aws_iam_role.this.arn` in instance profile | Use `.name` not `.arn` |
| `role = aws_iam_role.this.name` in role policy | Use `.id` not `.name` |
| `iam_instance_profile = aws_iam_instance_profile.this.id` | Use `.name` not `.id` |
| `Principal = { type = "*" }` for public access | Use `Principal = "*"` (string not object) |
| `assume_role_policy = data.aws_iam_policy_document.permissions.json` | Trust policy goes on role, not permissions |