# AWS Step Function to stop RDS & Aurora databases after forced 7th-day start
# github.com/sqlxpert/step-stay-stopped-aws-rds-aurora GPLv3 Copyright Marcelinƒ



data "aws_iam_policy" "step_stay_stopped_rds_do_role_local" {
  count = var.step_stay_stopped_rds_params["StepFnRoleAttachLocalPolicyName"] == "" ? 0 : 1

  name = var.step_stay_stopped_rds_params["StepFnRoleAttachLocalPolicyName"]
}



data "aws_kms_key" "step_stay_stopped_rds_step_function" {
  count = var.step_stay_stopped_rds_params["StepFnKmsKey"] == "" ? 0 : 1

  region = local.region
  key_id = provider::aws::arn_build(
    local.partition,
    "kms", # service
    local.region,
    split(":", var.step_stay_stopped_rds_params["StepFnKmsKey"])[0], # account
    split(":", var.step_stay_stopped_rds_params["StepFnKmsKey"])[1]  # resource (key/KEY_ID)
  )
}



data "aws_kms_alias" "aws_sqs" {
  count = var.step_stay_stopped_rds_params["SqsKmsKey"] == "alias/aws/sqs" ? 1 : 0

  region = local.region
  name   = "alias/aws/sqs"
}

data "aws_kms_key" "step_stay_stopped_rds_sqs" {
  count = contains(["", "alias/aws/sqs"], var.step_stay_stopped_rds_params["SqsKmsKey"]) ? 0 : 1

  region = local.region
  key_id = provider::aws::arn_build(
    local.partition,
    "kms", # service
    local.region,
    split(":", var.step_stay_stopped_rds_params["SqsKmsKey"])[0], # account
    split(":", var.step_stay_stopped_rds_params["SqsKmsKey"])[1]  # resource (key/KEY_ID)
  )
  # Provider functions added in Terraform v1.8.0
  # arn_build added in Terraform AWS provider v5.40.0
}



data "aws_kms_key" "step_stay_stopped_rds_cloudwatch_logs" {
  count = var.step_stay_stopped_rds_params["CloudWatchLogsKmsKey"] == "" ? 0 : 1

  region = local.region
  key_id = provider::aws::arn_build(
    local.partition,
    "kms", # service
    local.region,
    split(":", var.step_stay_stopped_rds_params["CloudWatchLogsKmsKey"])[0], # account
    split(":", var.step_stay_stopped_rds_params["CloudWatchLogsKmsKey"])[1]  # resource (key/KEY_ID)
  )
}



locals {
  step_stay_stopped_rds_params = merge(
    var.step_stay_stopped_rds_params,
    {
      StepFnRoleAttachLocalPolicyName = try(
        data.aws_iam_policy.step_stay_stopped_rds_do_role_local[0].name,
        ""
      )

      StepFnKmsKey = try(
        join(":", [
          provider::aws::arn_parse(data.aws_kms_key.step_stay_stopped_rds_step_function[0].arn)["account_id"],
          provider::aws::arn_parse(data.aws_kms_key.step_stay_stopped_rds_step_function[0].arn)["resource"],
        ]),
        ""
      )
      SqsKmsKey = try(
        data.aws_kms_alias.aws_sqs[0].name,
        join(":", [
          provider::aws::arn_parse(data.aws_kms_key.step_stay_stopped_rds_sqs[0].arn)["account_id"],
          provider::aws::arn_parse(data.aws_kms_key.step_stay_stopped_rds_sqs[0].arn)["resource"],
        ]),
        ""
      )
      CloudWatchLogsKmsKey = try(
        join(":", [
          provider::aws::arn_parse(data.aws_kms_key.step_stay_stopped_rds_cloudwatch_logs[0].arn)["account_id"],
          provider::aws::arn_parse(data.aws_kms_key.step_stay_stopped_rds_cloudwatch_logs[0].arn)["resource"],
        ]),
        ""
      )
    }
  )
}



resource "aws_cloudformation_stack" "step_stay_stopped_rds_prereq" {
  name          = "StepStayStoppedRdsAuroraPrereq${var.step_stay_stopped_rds_stack_name_suffix}"
  template_body = file("${local.cloudformation_path}/step_stay_stopped_aws_rds_aurora_prereq.yaml")

  region = local.region

  capabilities = ["CAPABILITY_IAM"]
  policy_body = file(
    "${local.cloudformation_path}/step_stay_stopped_aws_rds_aurora_prereq_policy.json"
  )

  tags = local.step_stay_stopped_rds_tags
}

data "aws_iam_role" "step_stay_stopped_rds_deploy" {
  name = aws_cloudformation_stack.step_stay_stopped_rds_prereq.outputs["DeploymentRoleName"]
}



resource "aws_cloudformation_stack" "step_stay_stopped" {
  name          = "StepStayStoppedRdsAurora${var.step_stay_stopped_rds_stack_name_suffix}"
  template_body = file("${local.cloudformation_path}/step_stay_stopped_aws_rds_aurora.yaml")

  region = local.region

  capabilities = ["CAPABILITY_IAM"]
  iam_role_arn = data.aws_iam_role.step_stay_stopped_rds_deploy.arn
  policy_body  = file("${local.cloudformation_path}/step_stay_stopped_aws_rds_aurora_policy.json")

  parameters = local.step_stay_stopped_rds_params

  tags = local.step_stay_stopped_rds_tags
}
