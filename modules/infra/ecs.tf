# ECS cluster + EC2 Spot capacity (frontend + backend on one small instance).
#
# Cost notes:
# - ECS control plane is free (unlike EKS ~$73/mo).
# - Pay only for the EC2 Spot t4g.small (and EBS). Toggle enable_ecs off when idle.
# - Instances sit in public subnets with a public IP so image pulls work without NAT.
# - Container Insights disabled to avoid CloudWatch ingestion cost.
# - Task definitions / services / ALB come later; this file is the compute foundation.

data "aws_ssm_parameter" "ecs_ami" {
  count = var.enable_ecs ? 1 : 0

  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/arm64/recommended/image_id"
}

data "aws_iam_policy_document" "ecs_instance_assume" {
  count = var.enable_ecs ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ecs_task_execution_assume" {
  count = var.enable_ecs ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_instance" {
  count = var.enable_ecs ? 1 : 0

  name               = "${local.name_prefix}-ecs-instance"
  assume_role_policy = data.aws_iam_policy_document.ecs_instance_assume[0].json

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-ecs-instance"
    Tier = "private"
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance" {
  count = var.enable_ecs ? 1 : 0

  role       = aws_iam_role.ecs_instance[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs" {
  count = var.enable_ecs ? 1 : 0

  name = "${local.name_prefix}-ecs-instance"
  role = aws_iam_role.ecs_instance[0].name

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-ecs-instance"
    Tier = "private"
  })
}

# Used by future task definitions to pull from ECR and read secrets.
resource "aws_iam_role" "ecs_task_execution" {
  count = var.enable_ecs ? 1 : 0

  name               = "${local.name_prefix}-ecs-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_assume[0].json

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-ecs-exec"
    Tier = "private"
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  count = var.enable_ecs ? 1 : 0

  role       = aws_iam_role.ecs_task_execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_cluster" "main" {
  count = var.enable_ecs ? 1 : 0

  name = "${local.name_prefix}-ecs"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-ecs"
    Tier = "private"
  })
}

resource "aws_launch_template" "ecs" {
  count = var.enable_ecs ? 1 : 0

  name_prefix   = "${local.name_prefix}-ecs-"
  image_id      = data.aws_ssm_parameter.ecs_ami[0].value
  instance_type = var.ecs_instance_type

  iam_instance_profile {
    arn = aws_iam_instance_profile.ecs[0].arn
  }

  # Public IP avoids NAT (~$32/mo) while still reaching ECR and the public internet.
  # Security groups must live on the ENI when network_interfaces is set.
  network_interfaces {
    device_index                = 0
    associate_public_ip_address = true
    security_groups             = [aws_security_group.app.id]
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.ecs_instance_disk_size_gb
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  dynamic "instance_market_options" {
    for_each = var.ecs_use_spot ? [1] : []

    content {
      market_type = "spot"
    }
  }

  user_data = base64encode(<<-EOT
    #!/bin/bash
    echo "ECS_CLUSTER=${aws_ecs_cluster.main[0].name}" >> /etc/ecs/ecs.config
    echo "ECS_ENABLE_SPOT_INSTANCE_DRAINING=true" >> /etc/ecs/ecs.config
  EOT
  )

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.resource_tags, {
      Name = "${local.name_prefix}-ecs-instance"
      Tier = "private"
    })
  }

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-ecs-lt"
    Tier = "private"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "ecs" {
  count = var.enable_ecs ? 1 : 0

  name_prefix         = "${local.name_prefix}-ecs-"
  vpc_zone_identifier = aws_subnet.public[*].id
  desired_capacity    = var.ecs_desired_capacity
  min_size            = var.ecs_min_capacity
  max_size            = var.ecs_max_capacity

  launch_template {
    id      = aws_launch_template.ecs[0].id
    version = "$Latest"
  }

  protect_from_scale_in = false

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-ecs-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_ecs_capacity_provider" "ec2" {
  count = var.enable_ecs ? 1 : 0

  name = "${local.name_prefix}-ec2"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs[0].arn
    managed_termination_protection = "DISABLED"

    managed_scaling {
      status                    = "ENABLED"
      target_capacity           = 100
      minimum_scaling_step_size = 1
      maximum_scaling_step_size = 1
    }
  }

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-ec2"
    Tier = "private"
  })
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  count = var.enable_ecs ? 1 : 0

  cluster_name       = aws_ecs_cluster.main[0].name
  capacity_providers = [aws_ecs_capacity_provider.ec2[0].name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ec2[0].name
    weight            = 1
    base              = 1
  }
}
