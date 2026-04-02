################################################################################
# Node Autoscaler - EKS Cluster
################################################################################

resource "cloudpilotai_eks_cluster" "this" {
  cluster_name = var.cluster_name
  region       = var.region

  aws_profile     = var.aws_profile
  kubeconfig      = var.kubeconfig
  custom_node_role = var.custom_node_role

  only_install_agent = var.only_install_agent
  enable_rebalance   = var.enable_rebalance

  skip_restore        = var.skip_restore
  restore_node_number = var.restore_node_number

  disable_workload_uploading         = var.disable_workload_uploading
  enable_upgrade_agent               = var.enable_upgrade_agent
  enable_upgrade_rebalance_component = var.enable_upgrade_rebalance_component
  enable_upload_config               = var.enable_upload_config
  enable_diversity_instance_type     = var.enable_diversity_instance_type

  nodeclass_templates = var.nodeclass_templates
  nodeclasses         = var.nodeclasses
  nodepool_templates  = var.nodepool_templates
  nodepools           = var.nodepools
  workload_templates  = var.workload_templates
  workloads           = var.workloads
}

################################################################################
# Workload Autoscaler
################################################################################

resource "cloudpilotai_workload_autoscaler" "this" {
  count = var.enable_workload_autoscaler ? 1 : 0

  cluster_id = cloudpilotai_eks_cluster.this.cluster_id
  kubeconfig = cloudpilotai_eks_cluster.this.kubeconfig

  storage_class     = var.wa_storage_class
  enable_node_agent = var.wa_enable_node_agent
  enable_upgrade    = var.wa_enable_upgrade

  recommendation_policies = var.recommendation_policies
  autoscaling_policies    = var.autoscaling_policies
  enable_proactive        = var.enable_proactive
  disable_proactive       = var.disable_proactive
}
