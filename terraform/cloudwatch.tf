resource "aws_cloudwatch_metric_alarm" "validator_errors" {
  alarm_name          = "${var.project_name}-validator-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_description   = "Lambda validator reported at least one error."

  dimensions = {
    FunctionName = aws_lambda_function.validator.function_name
  }
}

# After maxReceiveCount = 5 on the ingest queue, poison messages land here.
resource "aws_cloudwatch_metric_alarm" "ingest_dlq_not_empty" {
  alarm_name          = "${var.project_name}-ingest-dlq-not-empty"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_description   = "Ingest DLQ has at least one message (clinic file failed processing)."

  dimensions = {
    QueueName = aws_sqs_queue.ingest_dlq.name
  }
}
