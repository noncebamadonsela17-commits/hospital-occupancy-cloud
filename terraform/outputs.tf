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
