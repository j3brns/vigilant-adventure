# -----------------------------------------------------------------------------
# Production Tenants
# -----------------------------------------------------------------------------
# Tenants are provisioned using for_each over the tenants variable.
# This approach scales better than individual module blocks.
#
# Add tenants via terraform.tfvars:
#
# tenants = {
#   "acme-corp" = {
#     name = "Acme Corporation"
#     tier = "enterprise"
#   }
#   "globex" = {
#     name = "Globex Industries"
#     tier = "professional"
#   }
# }
# -----------------------------------------------------------------------------

module "tenants" {
  source   = "../../modules/tenant"
  for_each = var.tenants

  tenant_id   = each.key
  tenant_name = each.value.name
  tier        = each.value.tier
  environment = "prod"

  tier_config = module.platform.tenant_tiers[each.value.tier]

  runtime_execution_role_arn  = module.platform.gateway_execution_role_arn
  memory_collection_arn       = module.platform.memory_collection_arn
  memory_collection_id        = module.platform.memory_collection_id
  tenant_registry_table_name  = module.platform.tenant_registry_table_name
  runtime_registry_table_name = module.platform.runtime_registry_table_name

  # Custom model access for enterprise tenants
  allowed_model_arns = length(each.value.custom_model_arns) > 0 ? each.value.custom_model_arns : [
    "arn:aws:bedrock:*::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0",
    "arn:aws:bedrock:*::foundation-model/anthropic.claude-3-haiku-20240307-v1:0"
  ]

  create_gitlab_repo         = each.value.create_gitlab
  gitlab_tenant_namespace_id = var.gitlab_tenant_namespace_id
  gitlab_agent_template_id   = var.gitlab_agent_template_id

  log_retention_days = 90

  tags = {
    CostCentre  = "tenant-${each.key}"
    Criticality = each.value.tier == "enterprise" ? "high" : "standard"
  }
}

# -----------------------------------------------------------------------------
# Tenant Outputs
# -----------------------------------------------------------------------------

output "tenants" {
  description = "Provisioned tenant details"
  value = {
    for k, v in module.tenants : k => {
      id                 = v.tenant_id
      execution_role_arn = v.execution_role_arn
      memory_namespace   = v.memory_namespace
      gitlab_repo_url    = v.gitlab_repo_url
      log_group          = v.log_group_name
    }
  }
}
