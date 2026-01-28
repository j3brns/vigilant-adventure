# -----------------------------------------------------------------------------
# Lambda Authoriser Module - Variables
# -----------------------------------------------------------------------------

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "agentcore"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# Token Validation Configuration
# -----------------------------------------------------------------------------

variable "jwks_uri" {
  description = "URI for JSON Web Key Set (for JWT signature validation)"
  type        = string
}

variable "token_issuer" {
  description = "Expected token issuer (iss claim)"
  type        = string
}

variable "expected_audience" {
  description = "Expected audience claim (aud) - typically the AgentCore Gateway identifier"
  type        = string
}

variable "jwks_secret_arn" {
  description = "Optional Secrets Manager ARN for cached JWKS (improves cold start)"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# Platform References
# -----------------------------------------------------------------------------

variable "tenant_registry_table_name" {
  description = "DynamoDB table name for tenant registry"
  type        = string
}

variable "tenant_registry_table_arn" {
  description = "DynamoDB table ARN for tenant registry"
  type        = string
}

variable "api_gateway_execution_arn" {
  description = "API Gateway execution ARN for Lambda permission"
  type        = string
}

# -----------------------------------------------------------------------------
# Observability
# -----------------------------------------------------------------------------

variable "log_level" {
  description = "Lambda log level"
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["DEBUG", "INFO", "WARN", "ERROR"], var.log_level)
    error_message = "log_level must be one of: DEBUG, INFO, WARN, ERROR"
  }
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}

variable "alarm_sns_topic_arn" {
  description = "Optional SNS topic ARN for CloudWatch alarms"
  type        = string
  default     = null
}
