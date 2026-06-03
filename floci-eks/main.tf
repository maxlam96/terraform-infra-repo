module "eks" {
  source = "../modules/eks"

  cluster_name = var.cluster_name
  environment  = var.environment
  owner        = var.owner
  project      = var.project
  tags         = var.tags

  vpc_id                                   = var.vpc_id
  private_subnet_ids                       = var.private_subnet_ids
  kubernetes_version                       = var.kubernetes_version
  cluster_log_retention_days               = var.cluster_log_retention_days
  enable_cluster_log_kms_key               = var.enable_cluster_log_kms_key
  enable_cluster_access_config             = var.enable_cluster_access_config
  autoscaling_mode                         = var.autoscaling_mode
  create_node_ingress_security_group_rules = var.create_node_ingress_security_group_rules
  create_node_egress_security_group_rule   = var.create_node_egress_security_group_rule
  create_managed_node_groups               = var.create_managed_node_groups
  create_self_managed_node_groups          = var.create_self_managed_node_groups
  create_floci_node_group_placeholders     = var.create_floci_node_group_placeholders
  self_managed_node_ami_id                 = var.self_managed_node_ami_id
  create_cluster_addons                    = var.create_cluster_addons
  node_groups                              = var.node_groups
  cluster_addons                           = var.cluster_addons
}
