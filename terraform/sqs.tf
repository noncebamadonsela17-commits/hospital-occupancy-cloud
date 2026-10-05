resource "aws_sqs_queue" "ingest" {
  name                       = "${var.project_name}-ingest"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 10
}

resource "aws_sqs_queue" "ingest_dlq" {
  name = "${var.project_name}-ingest-dlq"
}

resource "aws_sqs_queue_redrive_policy" "ingest" {
  queue_url = aws_sqs_queue.ingest.id
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.ingest_dlq.arn
    maxReceiveCount     = 5
  })
}

resource "aws_sqs_queue_policy" "ingest_from_s3" {
  queue_url = aws_sqs_queue.ingest.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3SendMessage"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.ingest.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_s3_bucket.bronze.arn
          }
        }
      }
    ]
  })
}
