# Least-privilege identities. Humans/laptops use IAM users (access keys
# created in the console — never in git). Lambda will assume the processor role.

locals {
  bronze_objects = "${aws_s3_bucket.bronze.arn}/bronze/*"
}

# --- Uploader: clinic laptop may PUT bronze CSVs only ---

resource "aws_iam_user" "uploader" {
  name = "${var.project_name}-uploader"
}

resource "aws_iam_user_policy" "uploader" {
  name = "${var.project_name}-uploader"
  user = aws_iam_user.uploader.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "PutBronzeObjects"
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts"]
        Resource = local.bronze_objects
      }
    ]
  })
}

# --- Processor: Lambda (Iteration 2) reads objects and drains SQS ---

resource "aws_iam_role" "processor" {
  name = "${var.project_name}-processor"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "processor" {
  name = "${var.project_name}-processor"
  role = aws_iam_role.processor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadBronzeObjects"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = local.bronze_objects
      },
      {
        Sid    = "ReceiveIngestQueue"
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = aws_sqs_queue.ingest.arn
      }
    ]
  })
}

# --- Auditor: read bronze (and later logs) without uploading or deleting ---

resource "aws_iam_user" "auditor" {
  name = "${var.project_name}-auditor"
}

resource "aws_iam_user_policy" "auditor" {
  name = "${var.project_name}-auditor"
  user = aws_iam_user.auditor.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListBronzeBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.bronze.arn
      },
      {
        Sid      = "GetBronzeObjects"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.bronze.arn}/*"
      }
    ]
  })
}
