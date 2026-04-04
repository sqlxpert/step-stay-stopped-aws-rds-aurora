# AWS Step Function to stop RDS & Aurora databases after forced 7th-day start
# github.com/sqlxpert/step-stay-stopped-aws-rds-aurora GPLv3 Copyright Marcelin

variable "scp_name_suffix" {
  type        = string
  description = "Service control policy name suffix, for blue/green deployments or other scenarios in which you install multiple instances of this module. If you have also installed the CloudFormation template equivalent to this Terraform module, this suffix must differ from the stack name(s)."

  default = "StepStayStoppedRdsAuroraScp"
}

variable "enable_scp" {
  type        = bool
  description = "Whether to apply the service control policy to its designated targets. Change this to false to detach the SCP but preserve the list of its targets."

  default = true
}

variable "scp_target_ids" {
  type        = list(string)
  description = "Up to 100 r- root ID strings, ou- organizational unit ID strings, and/or AWS account ID numbers to which the SCP will apply. To view the SCP before applying it, leave this empty, or start with enable_scp set to false . Exercise caution when applying this SCP, because it generally does reduce existing permissions."

  default = []
}

variable "exclude_tag_key" {
  type        = string
  description = "IAM principals subject to the SCP are not allowed to remove this tag from RDS/Aurora database instances or database clusters. If the parameter is set in your deployed Step-Stay-Stopped CloudFormation stack, CloudFormation StackSet, //terraform module, or //terraform-multi module, this should match. Otherwise, keep the default. exclude_tag_key and include_tag_key must be different. For tag key rules, see https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_Tagging.html#Overview.Tagging.Structure"

  default = "StayStopped-Exclude"
}

variable "include_tag_key" {
  type        = string
  description = "IAM principals subject to the SCP are not allowed to add this tag to RDS/Aurora database instances or database clusters. If the parameter is set in your deployed Step-Stay-Stopped CloudFormation stack, CloudFormation StackSet, //terraform module, or //terraform-multi module, this should match. Otherwise, keep the default. See exclude_tag_key for other important details."

  default = "StayStopped-Include"

  validation {
    error_message = "exclude_tag_key and include_tag_key must be different."

    condition = (
      var.exclude_tag_key != var.include_tag_key
    )
  }
}

variable "scp_principal_condition" {
  type        = string
  description = "One or more condition expressions determining which roles (or other IAM principals) are not allowed to remove the exclude tag from or add the include tag to RDS/Aurora database instances and database clusters, in AWS accounts subject to the SCP. Separate multiple expressions with commas. Follow Terraform string escape rules for double quotation marks (prefix with a backslash) and any IAM policy variables (double the dollar sign). The default means that a tagging request will be denied if it is not  made by the manage-rds role. (Separately, you would have to create the manage-rds role and attach an IAM policy allowing the role to read and change RDS/Aurora database instance and database cluster tags.) \"ForAnyValue:StringEquals\" is forbidden; to use this condition operator, write a custom policy. For condition operators, see https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements_condition_operators.html . For condition keys, see https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_condition-keys.html#condition-keys-principal-properties"

  default = "\"ArnNotLike\": { \"aws:PrincipalArn\": \"arn:aws:iam::*:role/manage-rds\" }"

  validation {
    error_message = "\"ForAnyValue:StringEquals\" is forbidden. To use this condition operator, write a custom policy."

    condition = length(regexall(
      "\"ForAnyValue:StringEquals\"",
      var.scp_principal_condition
    )) == 0
  }

  validation {
    error_message = "scp_principal_condition must not be blank."

    condition = (length(var.scp_principal_condition) >= 1)
  }
}

variable "scp_tags" {
  type        = map(string)
  description = "Tag map for the SCP. Keys, all optional, are tag keys. Values are tag values. This takes precedence over the Terraform AWS provider's default_tags and over tags attributes defined by the module. To remove tags defined by the module, set the terraform , name_suffix , source and rights tags to null ."

  default = {}
}
