# -----------------------------------------------------------------------------
# AgentCore Platform Module - Outputs
# -----------------------------------------------------------------------------
# These outputs are consumed by the tenant module and environment configurations.

# -----------------------------------------------------------------------------
# Gateway Outputs
# -----------------------------------------------------------------------------

output "gateway_id" {
  description = "AgentCore Gateway agent ID"
  value       = aws_bedrockagent_agent.gateway.id
}

output "gateway_arn" {
  description = "AgentCore Gateway agent ARN"
  value       = aws_bedrockagent_agent.gateway.agent_arn
}

output "gateway_execution_role_arn" {
  description = "IAM role ARN for Gateway execution"
  value       = aws_iam_role.gateway_execution.arn
}

# -----------------------------------------------------------------------------
# Memory Outputs
# -----------------------------------------------------------------------------

output "memory_collection_id" {
  description = "OpenSearch Serverless collection ID for Memory"
  value       = aws_opensearchserverless_collection.memory.id
}

output "memory_collection_arn" {
  description = "OpenSearch Serverless collection ARN for Memory"
  value       = aws_opensearchserverless_collection.memory.arn
}

output "memory_collection_endpoint" {
  description = "OpenSearch Serverless collection endpoint"
  value       = aws_opensearchserverless_collection.memory.collection_endpoint
}

# -----------------------------------------------------------------------------
# Registry Outputs
# -----------------------------------------------------------------------------

output "tenant_registry_table_name" {
  description = "DynamoDB table name for tenant registry"
  value       = aws_dynamodb_table.tenant_registry.name
}

output "tenant_registry_table_arn" {
  description = "DynamoDB table ARN for tenant registry"
  value       = aws_dynamodb_table.tenant_registry.arn
}

output "runtime_registry_table_name" {
  description = "DynamoDB table name for runtime registry"
  value       = aws_dynamodb_table.runtime_registry.name
}

output "runtime_registry_table_arn" {
  description = "DynamoDB table ARN for runtime registry"
  value       = aws_dynamodb_table.runtime_registry.arn
}

# -----------------------------------------------------------------------------
# IAM Outputs
# -----------------------------------------------------------------------------

output "platform_operations_role_arn" {
  description = "IAM role ARN for platform operations"
  value       = aws_iam_role.platform_operations.arn
}

# -----------------------------------------------------------------------------
# Configuration Outputs
# -----------------------------------------------------------------------------

output "tenant_tiers" {
  description = "Tenant tier configuration"
  value       = var.tenant_tiers
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}
