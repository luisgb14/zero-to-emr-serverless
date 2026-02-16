# --- Outputs: application, role, and values used by tests ---
output "application_id" {
  description = "EMR Serverless application ID"
  value       = aws_emrserverless_application.main.id
}

output "execution_role_arn" {
  description = "EMR Serverless execution role ARN"
  value       = aws_iam_role.emr_serverless_execution.arn
}

output "emr_studio_url" {
  description = "EMR Studio URL"
  value       = aws_emr_studio.main.url
}

output "bucket_name" {
  description = "S3 bucket (for tests)"
  value       = aws_s3_bucket.emr.id
}

output "log_group_name" {
  description = "CloudWatch log group (for tests)"
  value       = aws_cloudwatch_log_group.emr.name
}

output "region" {
  description = "AWS region (for tests)"
  value       = var.region
}
