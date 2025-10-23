# AWS Step Function to stop RDS & Aurora databases after forced 7th-day start
# github.com/sqlxpert/step-stay-stopped-aws-rds-aurora GPLv3 Copyright Marcelin



data "aws_region" "stay_stopped_rds_stackset" {
  for_each = toset(coalescelist(
    var.stay_stopped_rds_stackset_regions,
    [local.region]
  ))

  region = each.key
}



data "aws_organizations_organization" "current" {}
data "aws_organizations_organizational_unit" "stay_stopped_rds_stackset" {
  for_each = toset(
    var.stay_stopped_rds_stackset_organizational_unit_names
  )

  parent_id = data.aws_organizations_organization.current.roots[0].id
  name      = each.key
}



# Both aws_cloudformation_stack_set_instance and aws_cloudformation_stack_set
# need operation_preferences . Updating aws_cloudformation_stack_set.parameters
# affects all StackSet instances.

resource "aws_cloudformation_stack_set" "stay_stopped_rds" {
  name          = "StepStayStoppedRdsAurora${var.stay_stopped_rds_stack_name_suffix}"
  template_body = file("${local.cloudformation_path}/step_stay_stopped_aws_rds_aurora.yaml")

  region = local.region

  call_as          = var.stay_stopped_rds_stackset_call_as
  permission_model = "SERVICE_MANAGED"
  capabilities     = ["CAPABILITY_IAM"]

  operation_preferences {
    region_order = sort(
      keys(data.aws_region.stay_stopped_rds_stackset)
    )
    region_concurrency_type = "PARALLEL"
    max_concurrent_count    = 2
    failure_tolerance_count = 2
  }

  auto_deployment {
    enabled = false
  }

  parameters = merge(
    var.stay_stopped_rds_params,
    { Test = false } # Security: Prevent unintended use in production
  )

  tags = local.stay_stopped_rds_tags

  timeouts {
    update = "4h"
  }

  lifecycle {
    ignore_changes = [
      administration_role_arn,
      operation_preferences[0].region_order,
    ]
  }
}

resource "aws_cloudformation_stack_set_instance" "stay_stopped_rds" {
  for_each = data.aws_region.stay_stopped_rds_stackset

  stack_set_name = aws_cloudformation_stack_set.stay_stopped_rds.name

  call_as = var.stay_stopped_rds_stackset_call_as

  operation_preferences {
    region_order = sort(
      keys(data.aws_region.stay_stopped_rds_stackset)
    )
    region_concurrency_type = "PARALLEL"
    max_concurrent_count    = 2
    failure_tolerance_count = 2
  }

  stack_set_instance_region = each.value.region
  deployment_targets {
    organizational_unit_ids = sort([
      for organizational_unit_key, organizational_unit
      in data.aws_organizations_organizational_unit.stay_stopped_rds_stackset
      : organizational_unit.id
    ])
  }
  retain_stack = false

  timeouts {
    create = "4h"
    update = "4h"
    delete = "4h"
  }

  lifecycle {
    ignore_changes = [
      operation_preferences[0].region_order,
    ]
  }
}
