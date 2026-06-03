locals {
  cluster_name           = coalesce(var.cluster_name, "${var.project}-${var.environment}-eks")
  use_cluster_autoscaler = contains(["cluster-autoscaler", "both"], var.autoscaling_mode)
  use_karpenter          = contains(["karpenter", "both"], var.autoscaling_mode)

  common_tags = merge(
    {
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = var.owner
      Project     = var.project
    },
    var.tags
  )

  cluster_autoscaler_tags = local.use_cluster_autoscaler ? {
    "k8s.io/cluster-autoscaler/enabled"               = "true"
    "k8s.io/cluster-autoscaler/${local.cluster_name}" = "owned"
  } : {}

  karpenter_discovery_tags = local.use_karpenter ? {
    "karpenter.sh/discovery" = local.cluster_name
  } : {}
}

data "aws_iam_policy_document" "cluster_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "node_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# EKS Cluster Policy - Replaces AmazonEKSClusterPolicy
data "aws_iam_policy_document" "cluster_policy" {
  statement {
    sid    = "EKSServicePolicy"
    effect = "Allow"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeInstances",
      "ec2:CreateSecurityGroup",
      "ec2:DescribeTags",
      "ec2:CreateTags",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "kms:Decrypt",
      "kms:GenerateDataKey",
    ]
    resources = ["*"]
  }
}

# Node Worker Policy - Replaces AmazonEKSWorkerNodePolicy
data "aws_iam_policy_document" "node_worker_policy" {
  statement {
    sid    = "EKSWorkerNodePolicy"
    effect = "Allow"
    actions = [
      "ec2:AssociateAddress",
      "ec2:AttachNetworkInterface",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CreateNetworkInterface",
      "ec2:CreateSecurityGroup",
      "ec2:DeleteNetworkInterface",
      "ec2:DeleteSecurityGroup",
      "ec2:DescribeAddresses",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeNetworkInterfaceAttribute",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeTags",
      "ec2:DetachNetworkInterface",
      "ec2:ModifyNetworkInterfaceAttribute",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:CreateTags",
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeScalingActivities",
      "autoscaling:DescribeTags",
    ]
    resources = ["*"]
  }
}

# EKS CNI Policy - Replaces AmazonEKS_CNI_Policy
data "aws_iam_policy_document" "node_cni_policy" {
  statement {
    sid    = "EKSCNIPolicy"
    effect = "Allow"
    actions = [
      "ec2:AssignPrivateIpAddresses",
      "ec2:AttachNetworkInterface",
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeInstances",
      "ec2:DescribeTags",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeInstanceTypes",
      "ec2:DetachNetworkInterface",
      "ec2:ModifyNetworkInterfaceAttribute",
      "ec2:UnassignPrivateIpAddresses",
    ]
    resources = ["*"]
  }
}

# ECR Read-Only Policy - Replaces AmazonEC2ContainerRegistryReadOnly
data "aws_iam_policy_document" "node_ecr_read_policy" {
  statement {
    sid    = "ECRReadOnlyPolicy"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${local.cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume_role.json
  tags               = merge(local.common_tags, { Name = "${local.cluster_name}-cluster-role" })
}

resource "aws_iam_role_policy" "cluster" {
  name   = "${local.cluster_name}-cluster-policy"
  role   = aws_iam_role.cluster.id
  policy = data.aws_iam_policy_document.cluster_policy.json
}

resource "aws_iam_role" "node" {
  name               = "${local.cluster_name}-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_assume_role.json
  tags               = merge(local.common_tags, { Name = "${local.cluster_name}-node-role" })
}

resource "aws_iam_role_policy" "node_worker" {
  name   = "${local.cluster_name}-node-worker-policy"
  role   = aws_iam_role.node.id
  policy = data.aws_iam_policy_document.node_worker_policy.json
}

resource "aws_iam_role_policy" "node_cni" {
  name   = "${local.cluster_name}-node-cni-policy"
  role   = aws_iam_role.node.id
  policy = data.aws_iam_policy_document.node_cni_policy.json
}

resource "aws_iam_role_policy" "node_ecr_read" {
  name   = "${local.cluster_name}-node-ecr-read-policy"
  role   = aws_iam_role.node.id
  policy = data.aws_iam_policy_document.node_ecr_read_policy.json
}

data "aws_iam_policy_document" "karpenter" {
  count = local.use_karpenter ? 1 : 0

  statement {
    sid = "KarpenterReadClusterAndCloudState"
    actions = [
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeImages",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeInstances",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSpotPriceHistory",
      "ec2:DescribeSubnets",
      "eks:DescribeCluster",
      "pricing:GetProducts",
      "ssm:GetParameter",
    ]
    resources = ["*"]
  }

  statement {
    sid = "KarpenterManageCompute"
    actions = [
      "ec2:CreateFleet",
      "ec2:CreateLaunchTemplate",
      "ec2:CreateTags",
      "ec2:DeleteLaunchTemplate",
      "ec2:RunInstances",
      "ec2:TerminateInstances",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "KarpenterPassNodeRole"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.node.arn]
  }

  statement {
    sid = "KarpenterReadInterruptionQueue"
    actions = [
      "sqs:DeleteMessage",
      "sqs:GetQueueUrl",
      "sqs:ReceiveMessage",
    ]
    resources = [aws_sqs_queue.karpenter[0].arn]
  }
}

resource "aws_iam_policy" "karpenter" {
  count = local.use_karpenter ? 1 : 0

  name   = "${local.cluster_name}-karpenter-controller"
  policy = data.aws_iam_policy_document.karpenter[0].json
  tags   = merge(local.common_tags, { Name = "${local.cluster_name}-karpenter-controller-policy" })
}

resource "aws_iam_role_policy_attachment" "karpenter_node" {
  count = local.use_karpenter ? 1 : 0

  role       = aws_iam_role.node.name
  policy_arn = aws_iam_policy.karpenter[0].arn
}

resource "aws_kms_key" "cluster" {
  description             = "KMS key for EKS secrets encryption: ${local.cluster_name}"
  deletion_window_in_days = var.kms_deletion_window_in_days
  enable_key_rotation     = true
  tags                    = merge(local.common_tags, { Name = "${local.cluster_name}-kms" })
}

resource "aws_kms_alias" "cluster" {
  name          = "alias/${local.cluster_name}-eks"
  target_key_id = aws_kms_key.cluster.key_id
}

resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${local.cluster_name}/cluster"
  retention_in_days = var.cluster_log_retention_days
  kms_key_id        = aws_kms_key.cluster.arn
  tags              = merge(local.common_tags, { Name = "${local.cluster_name}-control-plane-logs" })
}

resource "aws_security_group" "cluster" {
  name        = "${local.cluster_name}-cluster-sg"
  description = "EKS cluster security group"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, local.karpenter_discovery_tags, {
    Name = "${local.cluster_name}-cluster-sg"
  })
}

resource "aws_security_group" "nodes" {
  name        = "${local.cluster_name}-nodes-sg"
  description = "EKS managed node group security group"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, local.karpenter_discovery_tags, {
    Name = "${local.cluster_name}-nodes-sg"
  })
}

resource "aws_security_group_rule" "cluster_ingress_from_nodes" {
  count = var.create_node_ingress_security_group_rules ? 1 : 0

  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.nodes.id
  description              = "Allow worker nodes to reach the Kubernetes API"
}

resource "aws_security_group_rule" "nodes_ingress_self" {
  count = var.create_node_ingress_security_group_rules ? 1 : 0

  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  security_group_id = aws_security_group.nodes.id
  self              = true
  description       = "Allow node-to-node communication"
}

resource "aws_security_group_rule" "nodes_egress_all" {
  count = var.create_node_egress_security_group_rule ? 1 : 0

  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = var.node_egress_cidr_blocks
  security_group_id = aws_security_group.nodes.id
  description       = "Allow node egress"
}

resource "aws_eks_cluster" "this" {
  name     = local.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  enabled_cluster_log_types = var.enabled_cluster_log_types

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = false
  }

  encryption_config {
    resources = ["secrets"]

    provider {
      key_arn = aws_kms_key.cluster.arn
    }
  }

  access_config {
    authentication_mode                         = var.authentication_mode
    bootstrap_cluster_creator_admin_permissions = false
  }

  tags = merge(local.common_tags, { Name = local.cluster_name })

  depends_on = [
    aws_cloudwatch_log_group.cluster,
    aws_iam_role_policy.cluster,
  ]
}

resource "aws_eks_node_group" "managed" {
  for_each = var.create_managed_node_groups ? var.node_groups : {}

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${local.cluster_name}-${each.key}"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_subnet_ids

  ami_type       = each.value.ami_type
  capacity_type  = each.value.capacity_type
  disk_size      = each.value.disk_size
  instance_types = each.value.instance_types
  labels         = each.value.labels

  scaling_config {
    desired_size = each.value.desired_size
    max_size     = each.value.max_size
    min_size     = each.value.min_size
  }

  update_config {
    max_unavailable = each.value.max_unavailable
  }

  tags = merge(local.common_tags, local.cluster_autoscaler_tags, local.karpenter_discovery_tags, each.value.tags, {
    Name = "${local.cluster_name}-${each.key}"
  })

  depends_on = [
    aws_iam_role_policy.node_worker,
    aws_iam_role_policy.node_cni,
    aws_iam_role_policy.node_ecr_read,
  ]
}

resource "aws_iam_instance_profile" "node" {
  count = var.create_self_managed_node_groups ? 1 : 0

  name = "${local.cluster_name}-node-instance-profile"
  role = aws_iam_role.node.name
  tags = merge(local.common_tags, { Name = "${local.cluster_name}-node-instance-profile" })
}

resource "aws_launch_template" "self_managed_node" {
  for_each = var.create_self_managed_node_groups ? var.node_groups : {}

  name_prefix            = "${local.cluster_name}-${each.key}-"
  image_id               = var.self_managed_node_ami_id
  instance_type          = each.value.instance_types[0]
  update_default_version = true
  user_data = base64encode(templatefile("${path.module}/templates/bootstrap.sh.tftpl", {
    cluster_name = aws_eks_cluster.this.name
  }))

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      encrypted             = true
      volume_size           = each.value.disk_size
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.node[0].name
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 2
    http_tokens                 = "required"
  }

  network_interfaces {
    associate_public_ip_address = false
    delete_on_termination       = true
    security_groups             = [aws_security_group.nodes.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, local.cluster_autoscaler_tags, local.karpenter_discovery_tags, each.value.tags, {
      Name = "${local.cluster_name}-${each.key}"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(local.common_tags, each.value.tags, {
      Name = "${local.cluster_name}-${each.key}-root"
    })
  }

  tags = merge(local.common_tags, local.karpenter_discovery_tags, each.value.tags, {
    Name = "${local.cluster_name}-${each.key}-launch-template"
  })

  depends_on = [
    aws_eks_cluster.this,
    aws_iam_role_policy.node_worker,
    aws_iam_role_policy.node_cni,
    aws_iam_role_policy.node_ecr_read,
  ]
}

resource "aws_autoscaling_group" "self_managed_node" {
  for_each = var.create_self_managed_node_groups ? var.node_groups : {}

  name                = "${local.cluster_name}-${each.key}"
  desired_capacity    = each.value.desired_size
  max_size            = each.value.max_size
  min_size            = each.value.min_size
  vpc_zone_identifier = var.private_subnet_ids

  launch_template {
    id      = aws_launch_template.self_managed_node[each.key].id
    version = "$Latest"
  }

  dynamic "tag" {
    for_each = merge(local.common_tags, local.cluster_autoscaler_tags, local.karpenter_discovery_tags, each.value.tags, {
      Name                                                     = "${local.cluster_name}-${each.key}"
      "eks.amazonaws.com/cluster-name"                         = local.cluster_name
      "k8s.io/cluster-autoscaler/node-template/label/workload" = each.key
    })

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  depends_on = [aws_eks_cluster.this]
}

resource "aws_sqs_queue" "karpenter_dlq" {
  count = local.use_karpenter ? 1 : 0

  name                      = "${local.cluster_name}-karpenter-interruptions-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
  tags                      = merge(local.common_tags, { Name = "${local.cluster_name}-karpenter-interruptions-dlq" })
}

resource "aws_sqs_queue" "karpenter" {
  count = local.use_karpenter ? 1 : 0

  name                      = "${local.cluster_name}-karpenter-interruptions"
  message_retention_seconds = 1209600
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.karpenter_dlq[0].arn
    maxReceiveCount     = 5
  })
  sqs_managed_sse_enabled = true
  tags                    = merge(local.common_tags, { Name = "${local.cluster_name}-karpenter-interruptions" })
}

resource "aws_cloudwatch_event_rule" "karpenter" {
  for_each = local.use_karpenter ? {
    health = {
      detail_type = ["AWS Health Event"]
      source      = ["aws.health"]
    }
    instance_rebalance = {
      detail_type = ["EC2 Instance Rebalance Recommendation"]
      source      = ["aws.ec2"]
    }
    instance_state_change = {
      detail_type = ["EC2 Instance State-change Notification"]
      source      = ["aws.ec2"]
    }
    spot_interruption = {
      detail_type = ["EC2 Spot Instance Interruption Warning"]
      source      = ["aws.ec2"]
    }
  } : {}

  name = "${local.cluster_name}-karpenter-${each.key}"
  event_pattern = jsonencode({
    detail-type = each.value.detail_type
    source      = each.value.source
  })
  tags = merge(local.common_tags, { Name = "${local.cluster_name}-karpenter-${each.key}" })
}

resource "aws_cloudwatch_event_target" "karpenter" {
  for_each = aws_cloudwatch_event_rule.karpenter

  rule = each.value.name
  arn  = aws_sqs_queue.karpenter[0].arn
}

data "aws_iam_policy_document" "karpenter_queue" {
  count = local.use_karpenter ? 1 : 0

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["sqs:*"]
    resources = [aws_sqs_queue.karpenter[0].arn]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid     = "AllowEventBridgeToSendKarpenterInterruptionEvents"
    actions = ["sqs:SendMessage"]
    resources = [
      aws_sqs_queue.karpenter[0].arn,
    ]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_sqs_queue_policy" "karpenter" {
  count = local.use_karpenter ? 1 : 0

  queue_url = aws_sqs_queue.karpenter[0].id
  policy    = data.aws_iam_policy_document.karpenter_queue[0].json
}

resource "aws_eks_addon" "this" {
  for_each = var.create_cluster_addons ? var.cluster_addons : {}

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = each.key
  addon_version               = each.value.addon_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = merge(local.common_tags, each.value.tags, { Name = "${local.cluster_name}-${each.key}" })

  depends_on = [aws_eks_node_group.managed]
}
