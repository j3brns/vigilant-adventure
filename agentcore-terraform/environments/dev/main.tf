# -----------------------------------------------------------------------------
# AgentCore Infrastructure - Development Environment
# -----------------------------------------------------------------------------
# This is the root configuration for the dev environment.
# It instantiates the platform, authoriser, and tenant modules.
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

  # Backend configuration - update with your S3 bucket
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "agentcore/dev/terraform.tfstate"
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
      Environment = "dev"
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
  environment = "dev"

  gateway_model       = "anthropic.claude-3-sonnet-20240229-v1:0"
  gateway_instruction = file("${path.module}/gateway-instruction.txt")
  session_ttl         = 1800

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
    CostCentre = "platform"
  }
}

# -----------------------------------------------------------------------------
# Authoriser Module
# -----------------------------------------------------------------------------

module "authoriser" {
  source = "../../modules/authoriser"

  name_prefix = "agentcore"
  environment = "dev"

  jwks_uri          = var.jwks_uri
  token_issuer      = var.token_issuer
  expected_audience = module.platform.gateway_id # Gateway ID as audience

  tenant_registry_table_name = module.platform.tenant_registry_table_name
  tenant_registry_table_arn  = module.platform.tenant_registry_table_arn
  api_gateway_execution_arn  = var.api_gateway_execution_arn

  log_level          = "DEBUG" # More verbose in dev
  log_retention_days = 7

  alarm_sns_topic_arn = var.alarm_sns_topic_arn

  tags = {
    CostCentre = "platform"
  }
}

# -----------------------------------------------------------------------------
# Tenants
# -----------------------------------------------------------------------------
# In dev, we provision a small set of test tenants.
# Production would likely use a separate tenants.tf file or
# read tenant definitions from a data source.

module "tenant_demo" {
  source = "../../modules/tenant"

  tenant_id   = "demo-tenant"
  tenant_name = "Demo Tenant"
  tier        = "professional"
  environment = "dev"

  tier_config = module.platform.tenant_tiers["professional"]

  runtime_execution_role_arn  = module.platform.gateway_execution_role_arn
  memory_collection_arn       = module.platform.memory_collection_arn
  memory_collection_id        = module.platform.memory_collection_id
  tenant_registry_table_name  = module.platform.tenant_registry_table_name
  runtime_registry_table_name = module.platform.runtime_registry_table_name

  create_gitlab_repo         = var.create_gitlab_repos
  gitlab_tenant_namespace_id = var.gitlab_tenant_namespace_id
  gitlab_agent_template_id   = var.gitlab_agent_template_id

  log_retention_days = 7

  tags = {
    CostCentre = "demo"
  }
}

module "tenant_test" {
  source = "../../modules/tenant"

  tenant_id   = "test-tenant"
  tenant_name = "Test Tenant"
  tier        = "free"
  environment = "dev"

  tier_config = module.platform.tenant_tiers["free"]

  runtime_execution_role_arn  = module.platform.gateway_execution_role_arn
  memory_collection_arn       = module.platform.memory_collection_arn
  memory_collection_id        = module.platform.memory_collection_id
  tenant_registry_table_name  = module.platform.tenant_registry_table_name
  runtime_registry_table_name = module.platform.runtime_registry_table_name

  create_gitlab_repo = false # No GitLab repo for test tenant

  log_retention_days = 7

  tags = {
    CostCentre = "testing"
  }
}

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

output "demo_tenant" {
  description = "Demo tenant details"
  value = {
    id                 = module.tenant_demo.tenant_id
    execution_role_arn = module.tenant_demo.execution_role_arn
    memory_namespace   = module.tenant_demo.memory_namespace
    gitlab_repo_url    = module.tenant_demo.gitlab_repo_url
  }
}
