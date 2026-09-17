# AWS Budgets is a global service. The API lives in us-east-1 even though
# all landing-zone resources (S3, SQS, IAM, Lambda) stay in af-south-1.

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project   = "hospital-occupancy-cloud"
      Owner     = "nonceba-mdonsela"
      ManagedBy = "terraform"
    }
  }
}

resource "aws_budgets_budget" "monthly" {
  provider = aws.us_east_1

  name         = "${var.project_name}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.budget_limit_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_notification_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_notification_email]
  }
}
