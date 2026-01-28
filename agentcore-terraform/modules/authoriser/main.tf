# -----------------------------------------------------------------------------
# Lambda Authoriser Module
# -----------------------------------------------------------------------------
# Provisions the Lambda authoriser that validates incoming requests to the
# AgentCore Gateway. Handles JWT validation, tenant identification, and
# audience claim verification.
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id    = data.aws_caller_identity.current.account_id
  region        = data.aws_region.current.name
  function_name = "${var.name_prefix}-authoriser-${var.environment}"

  common_tags = merge(var.tags, {
    Module      = "authoriser"
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

# -----------------------------------------------------------------------------
# Lambda Function
# -----------------------------------------------------------------------------

# Package the authoriser code
# NOTE: Run 'npm ci' in modules/authoriser/src/ before terraform apply
# The archive includes node_modules which must be present
data "archive_file" "authoriser" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/dist/authoriser.zip"
  excludes    = ["package-lock.json"]
}

resource "aws_lambda_function" "authoriser" {
  function_name    = local.function_name
  description      = "AgentCore Gateway authoriser - JWT validation and tenant identification"
  role             = aws_iam_role.authoriser_execution.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  timeout          = 10
  memory_size      = 256

  filename         = data.archive_file.authoriser.output_path
  source_code_hash = data.archive_file.authoriser.output_base64sha256

  environment {
    variables = {
      TENANT_REGISTRY_TABLE = var.tenant_registry_table_name
      JWKS_URI              = var.jwks_uri
      TOKEN_ISSUER          = var.token_issuer
      EXPECTED_AUDIENCE     = var.expected_audience
      LOG_LEVEL             = var.log_level
    }
  }

  tracing_config {
    mode = "Active"
  }

  tags = local.common_tags

  depends_on = [
    aws_cloudwatch_log_group.authoriser,
    aws_iam_role_policy_attachment.basic_execution
  ]
}

# -----------------------------------------------------------------------------
# IAM Role
# -----------------------------------------------------------------------------

resource "aws_iam_role" "authoriser_execution" {
  name = "${local.function_name}-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

# Basic Lambda execution (CloudWatch Logs)
resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.authoriser_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# X-Ray tracing
resource "aws_iam_role_policy_attachment" "xray" {
  role       = aws_iam_role.authoriser_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# DynamoDB access for tenant lookup
resource "aws_iam_role_policy" "authoriser_dynamodb" {
  name = "dynamodb-access"
  role = aws_iam_role.authoriser_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TenantRegistryRead"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query"
        ]
        Resource = [
          var.tenant_registry_table_arn,
          "${var.tenant_registry_table_arn}/index/*"
        ]
      }
    ]
  })
}

# Secrets Manager access for JWKS caching (optional)
resource "aws_iam_role_policy" "authoriser_secrets" {
  count = var.jwks_secret_arn != null ? 1 : 0

  name = "secrets-access"
  role = aws_iam_role.authoriser_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "JwksSecretRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.jwks_secret_arn
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "authoriser" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.log_retention_days

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Lambda Permission for API Gateway
# -----------------------------------------------------------------------------

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.authoriser.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.api_gateway_execution_arn}/*/*"
}

# -----------------------------------------------------------------------------
# CloudWatch Alarms
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "authoriser_errors" {
  alarm_name          = "${local.function_name}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Authoriser Lambda error rate exceeded threshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.authoriser.function_name
  }

  alarm_actions = var.alarm_sns_topic_arn != null ? [var.alarm_sns_topic_arn] : []

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "authoriser_duration" {
  alarm_name          = "${local.function_name}-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Average"
  threshold           = 5000 # 5 seconds
  alarm_description   = "Authoriser Lambda duration exceeded threshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.authoriser.function_name
  }

  alarm_actions = var.alarm_sns_topic_arn != null ? [var.alarm_sns_topic_arn] : []

  tags = local.common_tags
}
