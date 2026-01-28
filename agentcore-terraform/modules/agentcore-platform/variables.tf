# -----------------------------------------------------------------------------
# AgentCore Platform Module - Variables
# -----------------------------------------------------------------------------

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "agentcore"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod"
  }
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# Gateway Configuration
# -----------------------------------------------------------------------------

variable "gateway_model" {
  description = "Foundation model for the AgentCore Gateway"
  type        = string
  default     = "anthropic.claude-sonnet-4-20250514-v1:0"
}

variable "gateway_instruction" {
  description = "System instruction for the Gateway agent"
  type        = string
  default     = "You are a routing agent. Direct requests to the appropriate tenant agent."
}

variable "session_ttl" {
  description = "Idle session timeout in seconds"
  type        = number
  default     = 1800 # 30 minutes
}

# -----------------------------------------------------------------------------
# Memory Configuration
# -----------------------------------------------------------------------------

variable "vpc_endpoint_ids" {
  description = "VPC endpoint IDs for OpenSearch Serverless network policy"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# IAM Configuration
# -----------------------------------------------------------------------------

variable "platform_admin_principals" {
  description = "ARNs of principals allowed to assume the platform operations role"
  type        = list(string)
}

# -----------------------------------------------------------------------------
# Tenant Tiers
# -----------------------------------------------------------------------------

variable "tenant_tiers" {
  description = "Configuration for each tenant tier"
  type = map(object({
    rate_limit_rps       = number
    memory_quota_gb      = number
    concurrent_sessions  = number
    features             = list(string)
  }))
  default = {
    free = {
      rate_limit_rps      = 10
      memory_quota_gb     = 1
      concurrent_sessions = 5
      features            = ["basic"]
    }
    professional = {
      rate_limit_rps      = 100
      memory_quota_gb     = 10
      concurrent_sessions = 50
      features            = ["basic", "advanced", "priority_support"]
    }
    enterprise = {
      rate_limit_rps      = 1000
      memory_quota_gb     = 100
      concurrent_sessions = 500
      features            = ["basic", "advanced", "priority_support", "dedicated", "sla"]
    }
  }
}
