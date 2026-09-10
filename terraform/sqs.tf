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
