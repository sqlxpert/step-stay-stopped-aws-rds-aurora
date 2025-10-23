# AWS Step Function to stop RDS & Aurora databases after forced 7th-day start
# github.com/sqlxpert/step-stay-stopped-aws-rds-aurora GPLv3 Copyright Marcelin

plugin "aws" {
  enabled = true
  version = "0.43.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
