# -----------------------------------------------------------------------------
# Tenant Module - Variables
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Tenant Identity
# -----------------------------------------------------------------------------

variable "tenant_id" {
  description = "Unique identifier for the tenant (used in resource naming and isolation)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.tenant_id))
    error_message = "tenant_id must be lowercase alphanumeric with hyphens only"
  }
}

variable "tenant_name" {
  description = "Human-readable tenant name"
  type        = string
}

variable "tier" {
  description = "Tenant tier (free, professional, enterprise)"
  type        = string

  validation {
    condition     = contains(["free", "professional", "enterprise"], var.tier)
    error_message = "tier must be one of: free, professional, enterprise"
  }
}

variable "tier_config" {
  description = "Configuration for the tenant's tier"
  type = object({
    rate_limit_rps      = number
    memory_quota_gb     = number
    concurrent_sessions = number
    features            = list(string)
  })
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "tags" {
  description = "Additional tags to apply to tenant resources"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# Platform References
# -----------------------------------------------------------------------------

variable "runtime_execution_role_arn" {
  description = "ARN of the AgentCore Runtime execution role (allowed to assume tenant roles)"
  type        = string
}

variable "memory_collection_arn" {
  description = "ARN of the OpenSearch Serverless collection for Memory"
  type        = string
}

variable "memory_collection_id" {
  description = "ID of the OpenSearch Serverless collection for Memory"
  type        = string
}

variable "tenant_registry_table_name" {
  description = "DynamoDB table name for tenant registry"
  type        = string
}

variable "runtime_registry_table_name" {
  description = "DynamoDB table name for runtime registry"
  type        = string
}

# -----------------------------------------------------------------------------
# Bedrock Configuration
# -----------------------------------------------------------------------------

variable "allowed_model_arns" {
  description = "List of Bedrock model ARNs the tenant can invoke"
  type        = list(string)
  default = [
    # Claude 4 Sonnet (Strands SDK default)
    "arn:aws:bedrock:*::foundation-model/anthropic.claude-sonnet-4-20250514-v1:0",
    # Cross-region inference profiles
    "arn:aws:bedrock:*:*:inference-profile/us.anthropic.claude-sonnet-4-20250514-v1:0",
    "arn:aws:bedrock:*:*:inference-profile/eu.anthropic.claude-sonnet-4-20250514-v1:0",
    # Claude 3 models (fallback)
    "arn:aws:bedrock:*::foundation-model/anthropic.claude-3-5-sonnet-20241022-v2:0",
    "arn:aws:bedrock:*::foundation-model/anthropic.claude-3-haiku-20240307-v1:0"
  ]
}

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

# -----------------------------------------------------------------------------
# GitLab Integration
# -----------------------------------------------------------------------------

variable "create_gitlab_repo" {
  description = "Whether to create a GitLab repository for the tenant"
  type        = bool
  default     = true
}

variable "gitlab_tenant_namespace_id" {
  description = "GitLab namespace ID for tenant repositories"
  type        = number
  default     = null
}

variable "gitlab_agent_template_id" {
  description = "GitLab project ID of the agent template repository"
  type        = number
  default     = null
}

variable "gitlab_agent_template_name" {
  description = "Name of the agent template to use"
  type        = string
  default     = "agentcore-agent-template"
}
