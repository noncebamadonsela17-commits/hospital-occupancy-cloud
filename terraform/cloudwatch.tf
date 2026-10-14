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
