variable "aws_region" {
  type        = string
  description = "AWS region. Cape Town is af-south-1."
  default     = "af-south-1"
}

variable "project_name" {
  type        = string
  description = "Prefix for unique resource names."
  default     = "hosp-occ"
}

variable "budget_limit_usd" {
  type        = number
  description = "Monthly budget alert in USD (student guardrail)."
  default     = 10
}
