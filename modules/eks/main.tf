locals {
  cluster_name = coalesce(var.cluster_name, "${var.project}-${var.environment}-eks")

  common_tags = merge(
    {
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = var.owner
      Project     = var.project
    },
    var.tags
  )
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

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-cluster-sg"
  })
}

resource "aws_security_group" "nodes" {
  name        = "${local.cluster_name}-nodes-sg"
  description = "EKS managed node group security group"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-nodes-sg"
  })
}

resource "aws_security_group_rule" "cluster_ingress_from_nodes" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.nodes.id
  description              = "Allow worker nodes to reach the Kubernetes API"
}

resource "aws_security_group_rule" "nodes_ingress_self" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  security_group_id = aws_security_group.nodes.id
  self              = true
  description       = "Allow node-to-node communication"
}

resource "aws_security_group_rule" "nodes_egress_all" {
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
  for_each = var.node_groups

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

  tags = merge(local.common_tags, each.value.tags, {
    Name = "${local.cluster_name}-${each.key}"
  })

  depends_on = [
    aws_iam_role_policy.node_worker,
    aws_iam_role_policy.node_cni,
    aws_iam_role_policy.node_ecr_read,
  ]
}

resource "aws_eks_addon" "this" {
  for_each = var.cluster_addons

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = each.key
  addon_version               = each.value.addon_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = merge(local.common_tags, each.value.tags, { Name = "${local.cluster_name}-${each.key}" })

  depends_on = [aws_eks_node_group.managed]
}
