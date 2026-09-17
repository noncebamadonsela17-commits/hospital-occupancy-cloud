output "bronze_bucket" {
  value       = aws_s3_bucket.bronze.id
  description = "S3 bucket for clinic CSV uploads."
}

output "ingest_queue_url" {
  value       = aws_sqs_queue.ingest.url
  description = "SQS queue that buffers new objects."
}

output "aws_region" {
  value = var.aws_region
}

output "uploader_user_arn" {
  value       = aws_iam_user.uploader.arn
  description = "Clinic identity: PutObject on bronze/ only. Create access keys in the console, not in git."
}

output "processor_role_arn" {
  value       = aws_iam_role.processor.arn
  description = "Lambda execution role: GetObject + SQS receive/delete."
}

output "auditor_user_arn" {
  value       = aws_iam_user.auditor.arn
  description = "Read-only identity: ListBucket + GetObject."
}
