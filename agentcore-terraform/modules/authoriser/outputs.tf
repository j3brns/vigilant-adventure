# -----------------------------------------------------------------------------
# Lambda Authoriser Module - Outputs
# -----------------------------------------------------------------------------

output "function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.authoriser.function_name
}

output "function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.authoriser.arn
}

output "invoke_arn" {
  description = "Lambda function invoke ARN (for API Gateway integration)"
  value       = aws_lambda_function.authoriser.invoke_arn
}

output "execution_role_arn" {
  description = "Lambda execution role ARN"
  value       = aws_iam_role.authoriser_execution.arn
}

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.authoriser.name
}

output "log_group_arn" {
  description = "CloudWatch log group ARN"
  value       = aws_cloudwatch_log_group.authoriser.arn
}
