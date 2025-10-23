# AWS Step Function to stop RDS & Aurora databases after forced 7th-day start
# github.com/sqlxpert/step-stay-stopped-aws-rds-aurora GPLv3 Copyright Marcelin



variable "stay_stopped_rds_stack_name_suffix" {
  type        = string
  description = "Optional CloudFormation stack name suffix, for blue/green deployments or other scenarios in which multiple stacks created from the same template are needed in the same region, in the same AWS account."

  default = ""
}

# You may wish to customize this interface, for example by omitting IAM role
# and policy names, the AWS Backup vault name, and KMS key identifiers in
# favor of looking up those resources based on tags.

variable "stay_stopped_rds_params" {
  type = object({
    Enable             = optional(bool, true)
    FollowUntilStopped = optional(bool, true)

    ExcludeTagKey = optional(string, "StayStopped-Exclude")
    IncludeTagKey = optional(string, "")

    Test = optional(bool, false)

    # If set, will be referenced in data sources, so resources must exist:
    StepFnRoleAttachLocalPolicyName = optional(string, "")
    StepFnKmsKey                    = optional(string, "")
    SqsKmsKey                       = optional(string, "")
    CloudWatchLogsKmsKey            = optional(string, "")

    StepFnTaskTimeoutSeconds = optional(number, 30)
    StepFnWaitSeconds        = optional(number, 540)
    StepFnTimeoutSeconds     = optional(number, 86400)

    MaximumMessageSizeBytes       = optional(number, 32768)
    MessageRetentionPeriodSeconds = optional(number, 1209600)
    LogRetentionInDays            = optional(number, 14)
    IncludeExecutionDataInLog     = optional(bool, true)
    LogLevel                      = optional(string, "ERROR")

    # Repeat defaults from cloudformation/step_stay_stopped_aws_rds_aurora.yaml
  })

  description = "Step Stay-Stopped CloudFormation stack parameter map. Keys, all optional, are parameter names from cloudformation/step_stay_stopped_aws_rds_aurora.yaml ; parameters are described there. CloudFormation and Terraform data types match, except for Boolean parameters. Terraform converts bool values to CloudFormation String values automatically. Specifying a value other than the empty string for StepFnRoleAttachLocalPolicyName , StepFnKmsKey , SqsKmsKey or CloudWatchLogsKmsKey causes Terraform to look up the resource, which must exist."

  default = {}
}



variable "stay_stopped_rds_tags" {
  type        = map(string)
  description = "Tag map for CloudFormation stacks. Keys, all optional, are tag keys. Values are tag values. This takes precedence over the Terraform AWS provider's default_tags and over tags attributes defined by the module. To remove tags defined by the module, set the terraform and source tags to null . Warnings: Each AWS service may have different rules for tag key and tag value lengths, characters, and disallowed tag key or tag value contents. CloudFormation propagates stack tags to stack resources. CloudFormation requires stack tag values to be at least 1 character long; empty tag values are not allowed."

  default = {}

  validation {
    error_message = "CloudFormation requires stack tag values to be at least 1 character long; empty tag values are not allowed."

    condition = alltrue([
      for value in values(var.stay_stopped_rds_tags) : try(length(value) >= 1, true)
    ])
    # Use try to guard against length(null) . Allowing null is necessary here
    # as a means of preventing the setting of a given tag. The more explicit:
    #   (value == null) || (length(value) >= 1)
    # does not work with versions of Terraform released before 2024-12-16.
    # Error: Invalid value for "value" parameter: argument must not be null.
    # https://github.com/hashicorp/hcl/pull/713
  }
}



variable "stay_stopped_rds_region" {
  type        = string
  description = "Region code for the region in which to create CloudFormation stacks. The empty string causes the module to use the default region configured for the Terraform AWS provider."

  default = ""
}
