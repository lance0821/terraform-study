# output "all_members" {
#     value = local.all_members
# }

# output "unique_members" {
#     value = local.unique_members
# }

# output "member_count" {
#     value = local.member_count
# }

# output "server_map" {
#   value = local.server_map
# }

# output "web_servers" {
#     value = local.web_servers
# }

# output "server_roles" {
#     value = local.server_roles
# }

# output "resolved_sizes" {
#     value = local.resolved_sizes  
# }

# output "unknown_sizes" {
#     value = local.unknown_sizes
# }

# output "valid_requests" {
#     value = local.valid_requests
# }

# output "servers" {
#     value = local.servers
# }

# output "tag_map" {
#     value = local.tag_map
# }

# output "prod_servers" {
#     value = local.prod_servers
# }

# output "server_by_region" {
#     value = local.servers_by_region
# }

# output "server_with_tags" {
#     value = local.server_with_tags
# }

# output "server_map" {
#     value = local.servers_map
# }

# output "all_profile_names" {
#   value = aws_iam_instance_profile.this[*].name
# }

# output "all_profile_arns" {
#   value = aws_iam_instance_profile.this[*].arn
# }

# output "first_profile_name" {
#   value = aws_iam_instance_profile.this[0].name
# }

# output "roles_splat" {
#   value = aws_iam_role.by_name[*].name
# }

# output "roles_for" {
#   value = { for k, v in aws_iam_role.by_name : k => v.name }
# }

# output "web_role_name" {
#   value = aws_iam_role.by_name["web"].name
# }
# output "prod_infra"{
#     value = local.prod_infra
# }
# output "duplicate_key_infra"{
#     value = local.duplicate_key_infra
# }
# output "web_infra"{
#     value = local.web_infra
# }
# output "distinct_infra"{
#     value = local.distinct_infra
# }
# output "number_infra"{
#     value = local.number_infra
# }

# output "infra" {
#     value = local.infra
# }

# output "infra_count" {
#     value = local.infra_count
# }

# output "distinct_prod_infra" {
#     value = local.distinct_prod_infra
# }

# output "az_tier_infra" {
#     value = local.az_tier_infra
# }

# output "infra_lg_xlg" {
#     value = local.infra_lg_xlg
# }

# output "az_tier_infra_final" {
#     value = local.az_tier_infra_final
# }

# output "profile_arns" {
#     value = {for k, v in aws_iam_instance_profile.this: k => v.arn }
# }

# output "prod_profile_arns" {
#     value = {for k, v in aws_iam_instance_profile.this: k => v.arn if var.infrastructure[k].env == "prod" }
# }