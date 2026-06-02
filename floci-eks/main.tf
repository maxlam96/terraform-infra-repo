module "eks" {
  source = "../modules/eks"

  cluster_name = var.cluster_name
  environment  = var.environment
  owner        = var.owner
  project      = var.project
  tags         = var.tags

  vpc_id                     = var.vpc_id
  private_subnet_ids         = var.private_subnet_ids
  kubernetes_version         = var.kubernetes_version
  cluster_log_retention_days = var.cluster_log_retention_days
  node_groups                = var.node_groups
  cluster_addons             = var.cluster_addons
}
