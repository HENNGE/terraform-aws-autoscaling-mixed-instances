#######################
# Launch template
#######################
resource "aws_launch_template" "this" {
  count = "${var.create_lt}"

  name_prefix           = "${coalesce(var.lt_name, var.name)}-"
  image_id              = "${var.image_id}"
  instance_type         = ""
  key_name              = "${var.key_name}"
  user_data             = "${base64encode(var.user_data)}"
  ebs_optimized         = "${var.ebs_optimized}"
  block_device_mappings = "${var.block_device_mappings}"

  iam_instance_profile {
    arn = "${var.iam_instance_profile}"
  }

  network_interfaces {
    description                 = "${coalesce(var.lt_name, var.name)}"
    device_index                = 0
    associate_public_ip_address = "${var.associate_public_ip_address}"
    delete_on_termination       = true
    security_groups             = ["${var.security_groups}"]
  }

  monitoring {
    enabled = "${var.enable_monitoring}"
  }

  placement {
    tenancy = "${var.placement_tenancy}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

####################
# Autoscaling group
####################
resource "aws_autoscaling_group" "this" {
  count = "${var.create_asg && !var.create_asg_with_initial_lifecycle_hook ? 1 : 0}"

  name_prefix         = "${join("-", compact(list(coalesce(var.asg_name, var.name), var.recreate_asg_when_lt_changes ? element(concat(random_pet.asg_name.*.id, list("")), 0) : "")))}-"
  vpc_zone_identifier = ["${var.vpc_zone_identifier}"]
  max_size            = "${var.max_size}"
  min_size            = "${var.min_size}"
  desired_capacity    = "${var.desired_capacity}"

  load_balancers            = ["${var.load_balancers}"]
  health_check_grace_period = "${var.health_check_grace_period}"
  health_check_type         = "${var.health_check_type}"

  min_elb_capacity          = "${var.min_elb_capacity}"
  wait_for_elb_capacity     = "${var.wait_for_elb_capacity}"
  target_group_arns         = ["${var.target_group_arns}"]
  default_cooldown          = "${var.default_cooldown}"
  force_delete              = "${var.force_delete}"
  termination_policies      = "${var.termination_policies}"
  suspended_processes       = "${var.suspended_processes}"
  placement_group           = "${var.placement_group}"
  enabled_metrics           = ["${var.enabled_metrics}"]
  metrics_granularity       = "${var.metrics_granularity}"
  wait_for_capacity_timeout = "${var.wait_for_capacity_timeout}"
  protect_from_scale_in     = "${var.protect_from_scale_in}"
  service_linked_role_arn   = "${var.service_linked_role_arn}"

  mixed_instances_policy {
    "launch_template" {
      "launch_template_specification" {
        launch_template_id = "${var.create_lt ? element(concat(aws_launch_template.this.*.id, list("")), 0) : var.launch_template}"
        version            = "$$Latest"
      }

      override = ["${local.instance_types}"]
    }
  }

  tags = ["${concat(
      list(map("key", "Name", "value", var.name, "propagate_at_launch", true)),
      var.tags,
      local.tags_asg_format
   )}"]

  lifecycle {
    create_before_destroy = true
  }
}

################################################
# Autoscaling group with initial lifecycle hook
################################################
resource "aws_autoscaling_group" "this_with_initial_lifecycle_hook" {
  count = "${var.create_asg && var.create_asg_with_initial_lifecycle_hook ? 1 : 0}"

  name_prefix         = "${join("-", compact(list(coalesce(var.asg_name, var.name), var.recreate_asg_when_lt_changes ? element(concat(random_pet.asg_name.*.id, list("")), 0) : "")))}-"
  vpc_zone_identifier = ["${var.vpc_zone_identifier}"]
  max_size            = "${var.max_size}"
  min_size            = "${var.min_size}"
  desired_capacity    = "${var.desired_capacity}"

  load_balancers            = ["${var.load_balancers}"]
  health_check_grace_period = "${var.health_check_grace_period}"
  health_check_type         = "${var.health_check_type}"

  min_elb_capacity          = "${var.min_elb_capacity}"
  wait_for_elb_capacity     = "${var.wait_for_elb_capacity}"
  target_group_arns         = ["${var.target_group_arns}"]
  default_cooldown          = "${var.default_cooldown}"
  force_delete              = "${var.force_delete}"
  termination_policies      = "${var.termination_policies}"
  suspended_processes       = "${var.suspended_processes}"
  placement_group           = "${var.placement_group}"
  enabled_metrics           = ["${var.enabled_metrics}"]
  metrics_granularity       = "${var.metrics_granularity}"
  wait_for_capacity_timeout = "${var.wait_for_capacity_timeout}"
  protect_from_scale_in     = "${var.protect_from_scale_in}"
  service_linked_role_arn   = "${var.service_linked_role_arn}"

  mixed_instances_policy {
    "launch_template" {
      "launch_template_specification" {
        launch_template_id = "${var.create_lt ? element(concat(aws_launch_template.this.*.id, list("")), 0) : var.launch_template}"
        version            = "$$Latest"
      }

      override = ["${local.instance_types}"]
    }
  }

  initial_lifecycle_hook {
    name                    = "${var.initial_lifecycle_hook_name}"
    lifecycle_transition    = "${var.initial_lifecycle_hook_lifecycle_transition}"
    notification_metadata   = "${var.initial_lifecycle_hook_notification_metadata}"
    heartbeat_timeout       = "${var.initial_lifecycle_hook_heartbeat_timeout}"
    notification_target_arn = "${var.initial_lifecycle_hook_notification_target_arn}"
    role_arn                = "${var.initial_lifecycle_hook_role_arn}"
    default_result          = "${var.initial_lifecycle_hook_default_result}"
  }

  tags = ["${concat(
      list(map("key", "Name", "value", var.name, "propagate_at_launch", true)),
      var.tags,
      local.tags_asg_format
   )}"]

  lifecycle {
    create_before_destroy = true
  }
}

resource "random_pet" "asg_name" {
  count = "${var.recreate_asg_when_lt_changes ? 1 : 0}"

  separator = "-"
  length    = 2

  keepers = {
    # Generate a new pet name each time we switch launch template
    lt_name = "${var.create_lt ? element(concat(aws_launch_template.this.*.name, list("")), 0) : var.launch_template}"
  }
}
