provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "hospital-occupancy-cloud"
      Owner     = "nonceba-mdonsela"
      ManagedBy = "terraform"
    }
  }
}
