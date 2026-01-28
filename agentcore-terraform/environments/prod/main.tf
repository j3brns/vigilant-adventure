# -----------------------------------------------------------------------------
# AgentCore Infrastructure - Production Environment
# -----------------------------------------------------------------------------
# Production configuration with stricter settings and longer retention.
# Tenant definitions would typically be managed separately or via a
# data-driven approach (reading from a config file or API).
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    gitlab = {
      source  = "gitlabhq/gitlab"
      version = "~> 16.0"
    }
  }

  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "agentcore/prod/terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "agentcore"
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}

provider "gitlab" {
  base_url = var.gitlab_base_url
  token    = var.gitlab_token
}

# -----------------------------------------------------------------------------
# Platform Module
# -----------------------------------------------------------------------------

module "platform" {
  source = "../../modules/agentcore-platform"

  name_prefix = "agentcore"
  environment = "prod"

  gateway_model       = "anthropic.claude-3-sonnet-20240229-v1:0"
  gateway_instruction = file("${path.module}/gateway-instruction.txt")
  session_ttl         = 3600 # 1 hour in prod

  vpc_endpoint_ids = var.vpc_endpoint_ids

  platform_admin_principals = var.platform_admin_principals

  tenant_tiers = {
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

  tags = {
    CostCentre  = "platform"
    Criticality = "high"
  }
}

# -----------------------------------------------------------------------------
# Authoriser Module
# -----------------------------------------------------------------------------

module "authoriser" {
  source = "../../modules/authoriser"

  name_prefix = "agentcore"
  environment = "prod"

  jwks_uri          = var.jwks_uri
  token_issuer      = var.token_issuer
  expected_audience = module.platform.gateway_id

  tenant_registry_table_name = module.platform.tenant_registry_table_name
  tenant_registry_table_arn  = module.platform.tenant_registry_table_arn
  api_gateway_execution_arn  = var.api_gateway_execution_arn

  log_level          = "INFO" # Less verbose in prod
  log_retention_days = 90     # Longer retention

  alarm_sns_topic_arn = var.alarm_sns_topic_arn

  tags = {
    CostCentre  = "platform"
    Criticality = "high"
  }
}

# -----------------------------------------------------------------------------
# Tenants
# -----------------------------------------------------------------------------
# Production tenants defined in a separate file for manageability.
# See tenants.tf for tenant module calls.
#
# Alternative approaches:
# - Read tenant list from JSON/YAML file using jsondecode(file(...))
# - Use for_each with a map of tenant configurations
# - Generate tenant modules from an external data source

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "gateway_id" {
  description = "AgentCore Gateway ID"
  value       = module.platform.gateway_id
}

output "gateway_arn" {
  description = "AgentCore Gateway ARN"
  value       = module.platform.gateway_arn
}

output "authoriser_function_arn" {
  description = "Lambda authoriser function ARN"
  value       = module.authoriser.function_arn
}

output "authoriser_invoke_arn" {
  description = "Lambda authoriser invoke ARN"
  value       = module.authoriser.invoke_arn
}

output "tenant_registry_table" {
  description = "Tenant registry DynamoDB table name"
  value       = module.platform.tenant_registry_table_name
}

output "memory_endpoint" {
  description = "OpenSearch Serverless endpoint for Memory"
  value       = module.platform.memory_collection_endpoint
}
