# AWS Step Function to stop RDS & Aurora databases after forced 7th-day start
# github.com/sqlxpert/step-stay-stopped-aws-rds-aurora GPLv3 Copyright Marcelin

output "scp_rds_protect_stay_stopped_tags_arn" {
  value       = aws_organizations_policy.scp_rds_protect_stay_stopped_tags.arn
  description = "ARN of service control policy policy protecting RDS/Aurora database stop exclude/include tags"
}
output "scp_rds_protect_stay_stopped_tags_id" {
  value       = aws_organizations_policy.scp_rds_protect_stay_stopped_tags.id
  description = "Physical identifier of service control policy"
}
