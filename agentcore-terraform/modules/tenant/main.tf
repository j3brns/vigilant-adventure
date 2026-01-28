# -----------------------------------------------------------------------------
# Tenant Module
# -----------------------------------------------------------------------------
# Provisions resources for a single tenant. Called once per tenant.
# 
# This module creates:
# - Tenant-specific IAM role (for agent execution with tenant isolation)
# - Memory namespace within the shared Memory service
# - Agent registration in the Runtime registry
# - Tenant record in the tenant registry
# - GitLab repository from template (optional)
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
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  # Normalise tenant_id for resource naming (lowercase, hyphens)
  tenant_slug = lower(replace(var.tenant_id, "_", "-"))

  common_tags = merge(var.tags, {
    Module    = "tenant"
    TenantId  = var.tenant_id
    Tier      = var.tier
    ManagedBy = "terraform"
  })
}

# -----------------------------------------------------------------------------
# Tenant IAM Role
# -----------------------------------------------------------------------------
# This role is assumed by the AgentCore Runtime when executing this tenant's
# agent. Session tags provide additional context for fine-grained access.

resource "aws_iam_role" "tenant_execution" {
  name = "agentcore-tenant-${local.tenant_slug}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = var.runtime_execution_role_arn
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.tenant_id
          }
        }
      },
      {
        Effect = "Allow"
        Principal = {
          AWS = var.runtime_execution_role_arn
        }
        Action = "sts:TagSession"
        Condition = {
          StringEquals = {
            "aws:RequestTag/TenantId" = var.tenant_id
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# Tenant-scoped permissions
resource "aws_iam_role_policy" "tenant_permissions" {
  name = "tenant-permissions"
  role = aws_iam_role.tenant_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "MemoryAccess"
        Effect = "Allow"
        Action = [
          "aoss:APIAccessAll"
        ]
        Resource = var.memory_collection_arn
        Condition = {
          StringEquals = {
            "aoss:collection" = var.memory_collection_id
          }
          StringLike = {
            # Namespace isolation - tenant can only access their namespace
            "aoss:index" = "tenant-${var.tenant_id}-*"
          }
        }
      },
      {
        Sid    = "BedrockInvoke"
        Effect = "Allow"
        Action = [
          # Legacy APIs
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
          # Converse APIs (used by Strands Agents SDK)
          "bedrock:Converse",
          "bedrock:ConverseStream"
        ]
        Resource = var.allowed_model_arns
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${local.region}:${local.account_id}:log-group:/agentcore/tenants/${var.tenant_id}:*"
      }
    ]
  })
}

# Additional permissions based on tier
resource "aws_iam_role_policy" "tenant_tier_permissions" {
  count = var.tier == "enterprise" ? 1 : 0

  name = "tenant-tier-permissions"
  role = aws_iam_role.tenant_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KnowledgeBaseAccess"
        Effect = "Allow"
        Action = [
          "bedrock:Retrieve",
          "bedrock:RetrieveAndGenerate"
        ]
        Resource = "arn:aws:bedrock:${local.region}:${local.account_id}:knowledge-base/*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/TenantId" = var.tenant_id
          }
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Tenant Registry Entry
# -----------------------------------------------------------------------------

resource "aws_dynamodb_table_item" "tenant_record" {
  table_name = var.tenant_registry_table_name
  hash_key   = "tenant_id"

  item = <<ITEM
{
  "tenant_id": {"S": "${var.tenant_id}"},
  "tenant_name": {"S": "${var.tenant_name}"},
  "tier": {"S": "${var.tier}"},
  "status": {"S": "active"},
  "execution_role_arn": {"S": "${aws_iam_role.tenant_execution.arn}"},
  "memory_namespace": {"S": "tenant-${var.tenant_id}"},
  "config": {
    "M": {
      "rate_limit_rps": {"N": "${var.tier_config.rate_limit_rps}"},
      "memory_quota_gb": {"N": "${var.tier_config.memory_quota_gb}"},
      "concurrent_sessions": {"N": "${var.tier_config.concurrent_sessions}"}
    }
  }
}
ITEM

  lifecycle {
    ignore_changes = [item]
  }
}

# -----------------------------------------------------------------------------
# Agent Registration
# -----------------------------------------------------------------------------

resource "aws_dynamodb_table_item" "agent_record" {
  table_name = var.runtime_registry_table_name
  hash_key   = "agent_id"

  item = <<ITEM
{
  "agent_id": {"S": "${var.tenant_id}-agent"},
  "tenant_id": {"S": "${var.tenant_id}"},
  "status": {"S": "registered"},
  "version": {"S": "0.0.0"}
}
ITEM

  lifecycle {
    ignore_changes = [item]
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "tenant_logs" {
  name              = "/agentcore/tenants/${var.tenant_id}"
  retention_in_days = var.log_retention_days

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# GitLab Repository (Optional)
# -----------------------------------------------------------------------------

resource "gitlab_project" "tenant_repo" {
  count = var.create_gitlab_repo ? 1 : 0

  name                   = "${local.tenant_slug}-agent"
  namespace_id           = var.gitlab_tenant_namespace_id
  description            = "AgentCore agent for ${var.tenant_name}"
  visibility_level       = "private"
  initialize_with_readme = false

  # Create from template
  template_name      = var.gitlab_agent_template_name
  template_project_id = var.gitlab_agent_template_id
  use_custom_template = true
}

# CI/CD variables for tenant pipeline
resource "gitlab_project_variable" "tenant_id" {
  count = var.create_gitlab_repo ? 1 : 0

  project   = gitlab_project.tenant_repo[0].id
  key       = "TENANT_ID"
  value     = var.tenant_id
  protected = false
  masked    = false
}

resource "gitlab_project_variable" "tenant_role_arn" {
  count = var.create_gitlab_repo ? 1 : 0

  project   = gitlab_project.tenant_repo[0].id
  key       = "TENANT_EXECUTION_ROLE_ARN"
  value     = aws_iam_role.tenant_execution.arn
  protected = true
  masked    = false
}

resource "gitlab_project_variable" "environment" {
  count = var.create_gitlab_repo ? 1 : 0

  project   = gitlab_project.tenant_repo[0].id
  key       = "ENVIRONMENT"
  value     = var.environment
  protected = false
  masked    = false
}
