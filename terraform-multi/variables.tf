# AWS Step Function to stop RDS & Aurora databases after forced 7th-day start
# github.com/sqlxpert/step-stay-stopped-aws-rds-aurora GPLv3 Copyright Marcelin



variable "stay_stopped_rds_stackset_name_suffix" {
  type        = string
  description = "Optional CloudFormation StackSet name suffix, for blue/green deployments or other scenarios in which multiple StackSets created from the same template are needed."

  default = ""
}



locals {
  stay_stopped_rds_stackset_call_as_values = [
    "SELF",
    "DELEGATED_ADMIN"
  ]

  stay_stopped_rds_stackset_call_as_values_string = join(
    " , ",
    local.stay_stopped_rds_stackset_call_as_values
  )
}

variable "stay_stopped_rds_stackset_call_as" {
  type        = string
  description = "The purpose of the AWS account from which the CloudFormation StackSet is being created: DELEGATED_ADMIN , or SELF for the management account."

  default = "SELF"

  validation {
    error_message = "value must be one of: ${local.stay_stopped_rds_stackset_call_as_values_string} ."

    condition = contains(
      local.stay_stopped_rds_stackset_call_as_values,
      var.stay_stopped_rds_stackset_call_as
    )
  }
}



variable "stay_stopped_rds_stackset_params" {
  type = object({
    Enable             = optional(bool, true)
    FollowUntilStopped = optional(bool, true)

    ExcludeTagKey = optional(string, "StayStopped-Exclude")
    IncludeTagKey = optional(string, "")

    Test = optional(bool, false) # Security: Accepted but forced to false later

    # If set, will be referenced in data sources, so resources must exist:
    StepFnRoleAttachLocalPolicyName = optional(string, "")
    StepFnKmsKey                    = optional(string, "")
    SqsKmsKey                       = optional(string, "")
    CloudWatchLogsKmsKey            = optional(string, "")

    ErrorQueueAdditionalPolicyStatements = optional(string, "")

    StepFnTaskTimeoutSeconds = optional(number, 30)
    StepFnWaitSeconds        = optional(number, 540)
    StepFnTimeoutSeconds     = optional(number, 86400)

    MaximumMessageSizeBytes       = optional(number, 32768)
    MessageRetentionPeriodSeconds = optional(number, 1209600)
    LogRetentionInDays            = optional(number, 14)
    IncludeExecutionDataInLog     = optional(bool, true)
    LogLevel                      = optional(string, "ERROR")

    PlaceholderSuggestedStackName       = optional(string, "")
    PlaceholderSuggestedStackPolicyBody = optional(string, "")
    PlaceholderHelp                     = optional(string, "")
    PlaceholderAdvancedParameters       = optional(string, "")

    # Repeat defaults from cloudformation/step_stay_stopped_aws_rds_aurora.yaml

    # For a StackSet, we must cover all parameters here or in
    # aws_cloudformation_stack_set.lifecycle.ignore_changes
  })

  description = "Step Stay-Stopped CloudFormation StackSet parameter map. Keys, all optional, are parameter names from cloudformation/step_stay_stopped_aws_rds_aurora.yaml ; parameters are described there. CloudFormation and Terraform data types match, except for Boolean parameters. Terraform converts bool values to CloudFormation String values automatically. In the StackSet, Test is always ignored and set to false , to prevent unintended use in production. Follow Terraform string escape rules for double quotation marks, etc. inside ErrorQueueAdditionalPolicyStatements ."

  default = {}
}

variable "stay_stopped_rds_tags" {
  type        = map(string)
  description = "Tag map for CloudFormation StackSet. Keys, all optional, are tag keys. Values are tag values. This takes precedence over the Terraform AWS provider's default_tags and over tags attributes defined by the module. To remove tags defined by the module, set the terraform and source tags to null . Warnings: Each AWS service may have different rules for tag key and tag value lengths, characters, and disallowed tag key or tag value contents. CloudFormation propagates StackSet tags to stack instances and to resources. CloudFormation requires stack tag values to be at least 1 character long; empty tag values are not allowed."

  default = {}

  validation {
    error_message = "CloudFormation requires StackSet tag values to be at least 1 character long; empty tag values are not allowed."

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



# You may wish to customize this interface. Beyond simply targeting a list of
# organizational units and a list of regions, CloudFormation supports a rich
# set of inputs for determining which AWS accounts to exclude and include, and
# lets you override StackSet parameters as necessary. See
# https://docs.aws.amazon.com/AWSCloudFormation/latest/APIReference/API_CreateStackInstances.html
# https://docs.aws.amazon.com/AWSCloudFormation/latest/APIReference/API_DeploymentTargets.html
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_set_instance#parameter_overrides-1

variable "stay_stopped_rds_stackset_organizational_unit_names" {
  type        = list(string)
  description = "List of the names (not the IDs) of the organizational units in which to create instances of the CloudFormation StackSet. At least one is required. The organizational units must exist. Within a region, deployments will always proceed in alphabetical order by OU ID (not by name)."

  validation {
    error_message = "At least one organizational unit name is required."

    condition = length(
      var.stay_stopped_rds_stackset_organizational_unit_names
    ) >= 1
  }
}

variable "stay_stopped_rds_stackset_regions" {
  type        = list(string)
  description = "List of region codes for the regions in which to create instances of the CloudFormation StackSet. The empty list causes the module to use stay_stopped_rds_region . Initial deployment will proceed in alphabetical order by region code."

  default = []
}



variable "stay_stopped_rds_region" {
  type        = string
  description = "Region code for the region from which to create the CloudFormation StackSet. The empty string causes the module to use the default region configured for the Terraform AWS provider."

  default = ""
}
