locals {
  nodeclass_templates = var.nodeclass_templates == null ? [] : var.nodeclass_templates
  nodeclasses         = var.nodeclasses == null ? null : var.nodeclasses
  nodepool_templates  = var.nodepool_templates == null ? [] : var.nodepool_templates
  nodepools           = var.nodepools == null ? null : var.nodepools
  workload_templates  = var.workload_templates == null ? [] : var.workload_templates
  workloads           = var.workloads == null ? null : var.workloads

  nodeclass_template_map = {
    for template in local.nodeclass_templates :
    try(template.template_name != null ? template.template_name : "", "") => {
      for key, value in template : key => value
      if key != "template_name" && value != null
    }
    if try(template.template_name != null ? template.template_name : "", "") != ""
  }

  rendered_nodeclasses = local.nodeclasses == null ? null : [
    for nodeclass in local.nodeclasses : merge(
      lookup(local.nodeclass_template_map, try(nodeclass.template_name != null ? nodeclass.template_name : "", ""), {}),
      {
        for key, value in nodeclass : key => value
        if key != "template_name" && value != null
      }
    )
  ]

  nodepool_template_map = {
    for template in local.nodepool_templates :
    try(template.template_name != null ? template.template_name : "", "") => {
      for key, value in template : key => value
      if key != "template_name" && value != null
    }
    if try(template.template_name != null ? template.template_name : "", "") != ""
  }

  rendered_nodepools = local.nodepools == null ? null : [
    for nodepool in local.nodepools : merge(
      lookup(local.nodepool_template_map, try(nodepool.template_name != null ? nodepool.template_name : "", ""), {}),
      {
        for key, value in nodepool : key => value
        if key != "template_name" && value != null
      }
    )
  ]

  workload_template_map = {
    for template in local.workload_templates :
    try(template.template_name != null ? template.template_name : "", "") => {
      for key, value in template : key => value
      if key != "template_name" && value != null
    }
    if try(template.template_name != null ? template.template_name : "", "") != ""
  }

  rendered_workloads = local.workloads == null ? null : [
    for workload in local.workloads : merge(
      lookup(local.workload_template_map, try(workload.template_name != null ? workload.template_name : "", ""), {}),
      {
        for key, value in workload : key => value
        if key != "template_name" && value != null
      }
    )
  ]
}
