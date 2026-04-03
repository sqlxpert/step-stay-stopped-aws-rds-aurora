# AWS Step Function to stop RDS & Aurora databases after forced 7th-day start
# github.com/sqlxpert/step-stay-stopped-aws-rds-aurora GPLv3 Copyright Marcelin

resource "aws_organizations_policy" "scp_rds_protect_stay_stopped_tags" {
  type        = "SERVICE_CONTROL_POLICY"
  name        = "RdsProtectTags-${var.scp_name_suffix}"
  description = "RDS/Aurora database instance or database cluster tags: Matching IAM principals cannot remove '${var.exclude_tag_key}' or add '${var.include_tag_key}'. GPLv3, Copyright Paul Marcelin. github.com/sqlxpert"
  tags        = local.scp_tags

  # I prefer data.aws_iam_policy_document , but a HEREDOC allows source parity
  # with CloudFormation (except for variables) and permits insertion of values
  # that the user specifies in JSON (native for the IAM policy language):
  content = <<-END_POLICY
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Deny",
          "Action": "rds:RemoveTagsFromResource",
          "Resource": [
            "${arn_build(local.partition, "rds", "*", "db", "*")}",
            "${arn_build(local.partition, "rds", "*", "cluster", "*")}"
          ],
          "Condition": {
            "ForAnyValue:StringEquals": {
              "aws:TagKeys": "${var.exclude_tag_key}"
            },
            ${var.scp_principal_condition}
          }
        },
        {
          "Effect": "Deny",
          "Action": "rds:AddTagsToResource",
          "Resource": [
            "${arn_build(local.partition, "rds", "*", "db", "*")}",
            "${arn_build(local.partition, "rds", "*", "cluster", "*")}"
          ],
          "Condition": {
            "ForAnyValue:StringEquals": {
              "aws:TagKeys": "${var.include_tag_key}"
            },
            ${var.scp_principal_condition}
          }
        }
      ]
    }
  END_POLICY
}

resource "aws_organizations_policy_attachment" "scp_rds_protect_stay_stopped_tags" {
  for_each = toset(var.enable_scp ? var.scp_target_ids : [])

  policy_id = aws_organizations_policy.scp_rds_protect_stay_stopped_tags.id
  target_id = each.key
}
