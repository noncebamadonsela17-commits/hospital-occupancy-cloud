data "archive_file" "validator" {
  type        = "zip"
  output_path = "${path.module}/build/validator.zip"

  source {
    content  = file("${path.module}/../lambda/handler.py")
    filename = "handler.py"
  }

  source {
    content  = file("${path.module}/../lambda/validate.py")
    filename = "validate.py"
  }
}

resource "aws_lambda_function" "validator" {
  function_name    = "${var.project_name}-validator"
  role             = aws_iam_role.processor.arn
  filename         = data.archive_file.validator.output_path
  source_code_hash = data.archive_file.validator.output_base64sha256
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 128
}

resource "aws_lambda_event_source_mapping" "ingest" {
  event_source_arn                   = aws_sqs_queue.ingest.arn
  function_name                      = aws_lambda_function.validator.arn
  batch_size                         = 1
  maximum_batching_window_in_seconds = 0
}
