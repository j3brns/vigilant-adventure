# -----------------------------------------------------------------------------
# AgentCore Platform Module
# -----------------------------------------------------------------------------
# Provisions the shared AgentCore infrastructure that all tenants use.
# This module creates the "platform" layer - individual tenants are
# provisioned separately via the tenant module.
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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

  # Standard tags applied to all resources
  common_tags = merge(var.tags, {
    Module      = "agentcore-platform"
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

# -----------------------------------------------------------------------------
# AgentCore Gateway
# -----------------------------------------------------------------------------
# The Gateway handles inbound requests, routes to agents, and integrates
# with the Lambda authoriser for authentication.

resource "aws_bedrockagent_agent" "gateway" {
  agent_name              = "${var.name_prefix}-gateway-${var.environment}"
  agent_resource_role_arn = aws_iam_role.gateway_execution.arn
  foundation_model        = var.gateway_model
  instruction             = var.gateway_instruction
  idle_session_ttl_in_seconds = var.session_ttl

  tags = local.common_tags
}

resource "aws_iam_role" "gateway_execution" {
  name = "${var.name_prefix}-gateway-execution-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:bedrock:${local.region}:${local.account_id}:agent/*"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "gateway_bedrock" {
  name = "bedrock-invoke"
  role = aws_iam_role.gateway_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = "arn:aws:bedrock:${local.region}::foundation-model/${var.gateway_model}"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# AgentCore Runtime
# -----------------------------------------------------------------------------
# The Runtime executes agent code. Tenants deploy their agents here.
# This is a placeholder - actual AgentCore Runtime resource TBC based on
# AWS service availability.

# TODO: Replace with actual AgentCore Runtime resource when available
# For now, this serves as a structural placeholder

resource "aws_dynamodb_table" "runtime_registry" {
  name         = "${var.name_prefix}-runtime-registry-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "agent_id"

  attribute {
    name = "agent_id"
    type = "S"
  }

  attribute {
    name = "tenant_id"
    type = "S"
  }

  global_secondary_index {
    name            = "tenant-index"
    hash_key        = "tenant_id"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# AgentCore Memory
# -----------------------------------------------------------------------------
# Shared memory service with tenant-isolated namespaces.

# TODO: Replace with actual AgentCore Memory resource when available
# Placeholder uses OpenSearch Serverless for vector storage

resource "aws_opensearchserverless_collection" "memory" {
  name        = "${var.name_prefix}-memory-${var.environment}"
  description = "AgentCore Memory - vector storage for agent context"
  type        = "VECTORSEARCH"

  tags = local.common_tags

  depends_on = [
    aws_opensearchserverless_security_policy.memory_encryption,
    aws_opensearchserverless_security_policy.memory_network
  ]
}

resource "aws_opensearchserverless_security_policy" "memory_encryption" {
  name = "${var.name_prefix}-memory-encryption-${var.environment}"
  type = "encryption"

  policy = jsonencode({
    Rules = [
      {
        Resource     = ["collection/${var.name_prefix}-memory-${var.environment}"]
        ResourceType = "collection"
      }
    ]
    AWSOwnedKey = true
  })
}

resource "aws_opensearchserverless_security_policy" "memory_network" {
  name        = "${var.name_prefix}-memory-network-${var.environment}"
  type        = "network"
  description = "Network access policy for AgentCore Memory"

  # Conditionally use VPC or public access based on whether VPC endpoints are provided
  policy = length(var.vpc_endpoint_ids) > 0 ? jsonencode([
    {
      Description = "VPC access for AgentCore Memory"
      Rules = [
        {
          Resource     = ["collection/${var.name_prefix}-memory-${var.environment}"]
          ResourceType = "collection"
        }
      ]
      AllowFromPublic = false
      SourceVPCEs     = var.vpc_endpoint_ids
    }
  ]) : jsonencode([
    {
      Description = "Public access for AgentCore Memory"
      Rules = [
        {
          Resource     = ["collection/${var.name_prefix}-memory-${var.environment}"]
          ResourceType = "collection"
        }
      ]
      AllowFromPublic = true
    }
  ])
}

# -----------------------------------------------------------------------------
# OpenSearch Access Policy
# -----------------------------------------------------------------------------
# Data access policy controlling who can read/write to the collection.

resource "aws_opensearchserverless_access_policy" "memory_data" {
  name        = "${var.name_prefix}-memory-data-${var.environment}"
  type        = "data"
  description = "Data access for AgentCore platform operations"

  policy = jsonencode([
    {
      Description = "Platform operations full access"
      Rules = [
        {
          ResourceType = "collection"
          Resource     = ["collection/${var.name_prefix}-memory-${var.environment}"]
          Permission   = ["aoss:*"]
        },
        {
          ResourceType = "index"
          Resource     = ["index/${var.name_prefix}-memory-${var.environment}/*"]
          Permission   = ["aoss:*"]
        }
      ]
      Principal = [aws_iam_role.platform_operations.arn]
    }
  ])
}

# -----------------------------------------------------------------------------
# Tenant Registry
# -----------------------------------------------------------------------------
# DynamoDB table storing tenant configuration and metadata.

resource "aws_dynamodb_table" "tenant_registry" {
  name         = "${var.name_prefix}-tenant-registry-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "tenant_id"

  attribute {
    name = "tenant_id"
    type = "S"
  }

  attribute {
    name = "tier"
    type = "S"
  }

  global_secondary_index {
    name            = "tier-index"
    hash_key        = "tier"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Platform IAM Role
# -----------------------------------------------------------------------------
# Role assumed by platform operations (CI/CD, management tasks).

resource "aws_iam_role" "platform_operations" {
  name = "${var.name_prefix}-platform-ops-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = var.platform_admin_principals
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "platform_operations" {
  name = "platform-operations"
  role = aws_iam_role.platform_operations.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DynamoDBAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.tenant_registry.arn,
          "${aws_dynamodb_table.tenant_registry.arn}/index/*",
          aws_dynamodb_table.runtime_registry.arn,
          "${aws_dynamodb_table.runtime_registry.arn}/index/*"
        ]
      },
      {
        Sid    = "OpenSearchAccess"
        Effect = "Allow"
        Action = [
          "aoss:APIAccessAll"
        ]
        Resource = aws_opensearchserverless_collection.memory.arn
      }
    ]
  })
}
