# -----------------------------------------------------------------------------
# Production Environment - Variables
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# AWS Configuration
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "eu-west-2"
}

variable "vpc_endpoint_ids" {
  description = "VPC endpoint IDs for OpenSearch Serverless network policy"
  type        = list(string)
  default     = []
}

variable "platform_admin_principals" {
  description = "ARNs of principals allowed to assume the platform operations role"
  type        = list(string)
}

# -----------------------------------------------------------------------------
# Authentication Configuration
# -----------------------------------------------------------------------------

variable "jwks_uri" {
  description = "URI for JSON Web Key Set (for JWT validation)"
  type        = string
}

variable "token_issuer" {
  description = "Expected JWT issuer (iss claim)"
  type        = string
}

variable "api_gateway_execution_arn" {
  description = "API Gateway execution ARN for Lambda authoriser permission"
  type        = string
}

# -----------------------------------------------------------------------------
# GitLab Configuration
# -----------------------------------------------------------------------------

variable "gitlab_base_url" {
  description = "GitLab instance URL"
  type        = string
  default     = "https://gitlab.internal"
}

variable "gitlab_token" {
  description = "GitLab API token"
  type        = string
  sensitive   = true
}

variable "create_gitlab_repos" {
  description = "Whether to create GitLab repositories for tenants"
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

# -----------------------------------------------------------------------------
# Tenant Configuration
# -----------------------------------------------------------------------------

variable "tenants" {
  description = "Map of tenant configurations"
  type = map(object({
    name             = string
    tier             = string
    create_gitlab    = optional(bool, true)
    custom_model_arns = optional(list(string), [])
  }))
  default = {}
}

# -----------------------------------------------------------------------------
# Observability
# -----------------------------------------------------------------------------

variable "alarm_sns_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarms"
  type        = string
  default     = null
}
