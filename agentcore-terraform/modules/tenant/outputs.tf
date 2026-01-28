# -----------------------------------------------------------------------------
# Tenant Module - Outputs
# -----------------------------------------------------------------------------

output "tenant_id" {
  description = "Tenant identifier"
  value       = var.tenant_id
}

output "execution_role_arn" {
  description = "IAM role ARN for tenant agent execution"
  value       = aws_iam_role.tenant_execution.arn
}

output "execution_role_name" {
  description = "IAM role name for tenant agent execution"
  value       = aws_iam_role.tenant_execution.name
}

output "memory_namespace" {
  description = "OpenSearch index namespace for tenant"
  value       = "tenant-${var.tenant_id}"
}

output "log_group_name" {
  description = "CloudWatch log group name for tenant"
  value       = aws_cloudwatch_log_group.tenant_logs.name
}

output "log_group_arn" {
  description = "CloudWatch log group ARN for tenant"
  value       = aws_cloudwatch_log_group.tenant_logs.arn
}

output "agent_id" {
  description = "Registered agent ID in runtime registry"
  value       = "${var.tenant_id}-agent"
}

output "gitlab_repo_url" {
  description = "GitLab repository URL for tenant agent code"
  value       = var.create_gitlab_repo ? gitlab_project.tenant_repo[0].http_url_to_repo : null
}

output "gitlab_repo_id" {
  description = "GitLab repository ID"
  value       = var.create_gitlab_repo ? gitlab_project.tenant_repo[0].id : null
}
