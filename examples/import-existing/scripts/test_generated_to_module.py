import unittest

import generated_to_module as converter


class GeneratedToModuleTest(unittest.TestCase):
    def test_nested_cluster_settings_preserve_null_commands(self):
        body = '''
  cluster_setting = {
    disruption_cooldown = "5m"
    aws_spot_allocation_strategy = "price-capacity-optimized"
    pre_run_command = null
    post_run_command = null
  }
'''
        output = "".join(converter.transform_cluster_body(body))
        self.assertIn('disruption_cooldown = "5m"', output)
        self.assertIn('aws_spot_allocation_strategy = "price-capacity-optimized"', output)
        self.assertIn("pre_run_command = null", output)
        self.assertIn("post_run_command = null", output)

    def test_legacy_cluster_settings_preserve_null_commands(self):
        output = converter.transform_cluster_setting_body('''
  cluster_id = "illustrative-cluster"
  pre_run_command = null
  post_run_command = null
''')
        self.assertIn("pre_run_command = null", output)
        self.assertIn("post_run_command = null", output)
        self.assertNotIn("cluster_id", output)

    def test_excluded_cluster_settings_are_removed(self):
        fields = (
            "maintenance_enabled", "saving_report_baseline_start_at",
            "saving_report_baseline_end_at", "memory_request_multiplier",
            "zero_memory_request_mib",
        )
        inner = "".join(f"    {name} = null\n" for name in fields)
        nested = "  cluster_setting = {\n" + inner + "    discount = null\n  }\n"
        output = "".join(converter.transform_cluster_body(nested))
        legacy = converter.transform_cluster_setting_body(inner.replace("    ", "  ") + "  discount = null\n")
        for name in fields:
            self.assertNotIn(name, output)
            self.assertNotIn(name, legacy)
        self.assertIn("discount = null", output)
        self.assertIn("discount = null", legacy)
        self.assertEqual(converter.strip_removed_cluster_setting_fields("  cluster_setting = {\n" + inner + "  }\n"), "")

    def test_null_cluster_setting_is_preserved(self):
        output = "".join(converter.transform_cluster_body("  cluster_setting = null\n"))
        self.assertEqual(output, "  cluster_setting = null\n")

    def test_released_nested_node_fields_are_preserved(self):
        body = '''
  nodeclasses = [{
    name = "illustrative-class"
    memory_extension = { enabled = false, cold_memory = { min_gib = null, max_gib = 16 } }
    block_device_mappings = [{ ebs = { volume_size_policy = { per_vcpu_gib = null, max_size_gib = 512 } } }]
  }]
  nodepools = [{
    name = "illustrative-pool"
    disruption_cooldown = "0s"
    nri_swap_policy = { enabled = false, memory_limit_multiplier = null }
    job_nodepool_optimization = { min_active_nodes = null, provisioning_delay = "30s" }
  }]
'''
        self.assertEqual("".join(converter.transform_cluster_body(body)), body.lstrip("\n"))

    def test_released_workload_autoscaler_fields_are_preserved(self):
        body = '''
  recommendation_policies = [{ name = "illustrative-steady", jvm_max_heap_xms = "2Gi", jvm_min_heap_xmx = null, jvm_max_heap_xmx = "4Gi" }]
  autoscaling_policies = [{ name = "illustrative-app", startup_boost_recommendation_policy_name = "illustrative-startup", startup_boost_update_resources = ["memory"] }]
  enable_proactive = [{ startup_boost_enabled = false }]
'''
        output, include = converter.transform_wa_body(body)
        self.assertTrue(include)
        self.assertEqual("".join(output), body.lstrip("\n"))

    def test_import_headers_support_terraform_and_opentofu(self):
        for cli in ("Terraform", "OpenTofu"):
            with self.subTest(cli=cli):
                generated = f'# __generated__ by {cli} from "illustrative-cluster"\nresource "cloudpilotai_eks_cluster" "imported" {{\n}}\n'
                self.assertEqual(converter.extract_import_id(generated, "cloudpilotai_eks_cluster"), "illustrative-cluster")

    def test_workload_autoscaler_access_fields_do_not_duplicate_cluster_inputs(self):
        cluster = '''
  cluster_id = "illustrative-cluster"
  cluster_name = "illustrative-eks"
  region = "us-west-2"
  aws_profile = null
  aws_assume_role = { role_arn = "arn:aws:iam::123456789012:role/illustrative-role" }
'''
        workload_autoscaler = '''
  cluster_id = "illustrative-cluster"
  kubeconfig = null
  aws_profile = "illustrative-wa-profile"
  aws_assume_role = null
  gcp_project_id = null
  gcp_cluster_location = null
  storage_class = "illustrative-storage"
  enable_node_agent = true
'''
        output = converter.build_module_file(cluster, None, workload_autoscaler, "../..")
        self.assertEqual(output.count("  aws_profile ="), 1)
        self.assertIn("  aws_profile = var.aws_profile", output)
        self.assertEqual(output.count("  aws_assume_role ="), 1)
        self.assertIn('role/illustrative-role"', output)
        self.assertNotIn("illustrative-wa-profile", output)
        self.assertNotIn("gcp_project_id", output)
        self.assertNotIn("gcp_cluster_location", output)
        self.assertNotIn("kubeconfig", output)
        self.assertIn('wa_storage_class = "illustrative-storage"', output)
        self.assertIn("wa_enable_node_agent = true", output)


if __name__ == "__main__":
    unittest.main()
