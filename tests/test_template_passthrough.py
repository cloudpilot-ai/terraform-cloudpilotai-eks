import json
import pathlib
import shutil
import subprocess
import tempfile
import unittest


MODULE_ROOT = pathlib.Path(__file__).resolve().parents[1]


class TemplatePassthroughTest(unittest.TestCase):
    def render(self, cli, variables):
        with tempfile.TemporaryDirectory(prefix="cloudpilot-eks-locals-") as directory:
            root = pathlib.Path(directory)
            for filename in ("variables.tf", "locals.tf"):
                shutil.copyfile(MODULE_ROOT / filename, root / filename)
            values = {"cluster_name": "illustrative-eks", "region": "us-west-2", **variables}
            (root / "inputs.tfvars.json").write_text(json.dumps(values))
            result = subprocess.run(
                [cli, "console", "-no-color", "-var-file=inputs.tfvars.json"],
                input="jsonencode({nodeclasses=local.rendered_nodeclasses,nodepools=local.rendered_nodepools,workloads=local.rendered_workloads})\n",
                cwd=root,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue(result.stdout.strip(), result.stderr)
            return json.loads(json.loads(result.stdout.strip()))

    def available_clis(self):
        available = [cli for cli in ("terraform", "tofu") if shutil.which(cli)]
        if not available:
            self.skipTest("Terraform or OpenTofu is required for template evaluation")
        return available

    def test_explicit_null_overrides_template_fields(self):
        for cli in self.available_clis():
            with self.subTest(cli=cli):
                result = self.render(cli, {
                    "nodeclass_templates": [{"template_name": "base", "memory_extension": {"enabled": True}}],
                    "nodeclasses": [{"name": "illustrative-class", "template_name": "base", "memory_extension": None}],
                    "nodepool_templates": [{"template_name": "base", "disruption_cooldown": "5m", "nri_swap_policy": {"enabled": True}}],
                    "nodepools": [{"name": "illustrative-pool", "template_name": "base", "disruption_cooldown": None, "nri_swap_policy": None}],
                    "workload_templates": [{"template_name": "base", "spot_friendly": True}],
                    "workloads": [{"name": "illustrative-app", "template_name": "base", "spot_friendly": None}],
                })
                self.assertIsNone(result["nodeclasses"][0]["memory_extension"])
                self.assertIsNone(result["nodepools"][0]["disruption_cooldown"])
                self.assertIsNone(result["nodepools"][0]["nri_swap_policy"])
                self.assertIsNone(result["workloads"][0]["spot_friendly"])

    def test_released_nested_fields_and_nulls_pass_through(self):
        nodeclass = {
            "name": "illustrative-class", "template_name": "base",
            "memory_extension": {"enabled": False, "cold_memory": {"min_gib": None, "max_gib": 16}, "cached_memory": {"max_memory_percent": 10}},
            "block_device_mappings": [{"device_name": "/dev/xvda", "root_volume": True, "ebs": {"volume_size_policy": {"per_vcpu_gib": 0, "max_size_gib": 512}}}],
        }
        nodepool = {
            "name": "illustrative-pool", "disruption_cooldown": "0s",
            "nri_swap_policy": {"enabled": False, "memory_limit_multiplier": None},
            "job_nodepool_optimization": {"min_active_nodes": None, "provisioning_delay": "30s"},
        }
        for cli in self.available_clis():
            with self.subTest(cli=cli):
                result = self.render(cli, {
                    "nodeclass_templates": [{"template_name": "base", "ami_alias": "al2023@latest"}],
                    "nodeclasses": [nodeclass], "nodepools": [nodepool], "workloads": None,
                })
                self.assertEqual(result["nodeclasses"][0], {**{k: v for k, v in nodeclass.items() if k != "template_name"}, "ami_alias": "al2023@latest"})
                self.assertEqual(result["nodepools"], [nodepool])
                self.assertIsNone(result["workloads"])

    def test_explicit_empty_policies_override_template_fields(self):
        template_disks = [{
            "device_name": "/dev/xvda", "ebs": {
                "volume_size": "80Gi",
                "volume_size_policy": {"per_vcpu_gib": 4, "max_size_gib": 512},
            },
        }]
        reset_disks = [{"device_name": "/dev/xvda", "ebs": {"volume_size_policy": {}}}]
        for cli in self.available_clis():
            with self.subTest(cli=cli):
                result = self.render(cli, {
                    "nodeclass_templates": [{
                        "template_name": "base", "memory_extension": {"enabled": True},
                        "block_device_mappings": template_disks,
                    }],
                    "nodeclasses": [{
                        "name": "illustrative-class", "template_name": "base",
                        "memory_extension": {}, "block_device_mappings": reset_disks,
                    }],
                    "nodepool_templates": [{
                        "template_name": "base", "disruption_cooldown": "5m",
                        "job_nodepool_optimization": {"min_active_nodes": 2},
                        "nri_swap_policy": {"enabled": True, "memory_limit_multiplier": "2"},
                    }],
                    "nodepools": [{
                        "name": "illustrative-pool", "template_name": "base",
                        "disruption_cooldown": "", "job_nodepool_optimization": {},
                        "nri_swap_policy": {},
                    }],
                })
                self.assertEqual(result["nodeclasses"][0]["memory_extension"], {})
                self.assertEqual(result["nodeclasses"][0]["block_device_mappings"], reset_disks)
                self.assertEqual(result["nodepools"][0]["job_nodepool_optimization"], {})
                self.assertEqual(result["nodepools"][0]["nri_swap_policy"], {})
                self.assertEqual(result["nodepools"][0]["disruption_cooldown"], "")

    def test_heterogeneous_templates_preserve_optional_fields(self):
        memory = {"enabled": True, "cold_memory": {"max_gib": 16}}
        job = {"min_active_nodes": 2}
        for cli in self.available_clis():
            with self.subTest(cli=cli):
                result = self.render(cli, {
                    "nodeclass_templates": [
                        {"template_name": "memory", "memory_extension": memory},
                        {"template_name": "basic", "ami_alias": "al2023@latest"},
                    ],
                    "nodeclasses": [
                        {"name": "memory-class", "template_name": "memory"},
                        {"name": "basic-class", "template_name": "basic"},
                    ],
                    "nodepool_templates": [
                        {"template_name": "cooldown", "disruption_cooldown": "5m"},
                        {"template_name": "job", "job_nodepool_optimization": job},
                    ],
                    "nodepools": [
                        {"name": "cooldown-pool", "template_name": "cooldown"},
                        {"name": "job-pool", "template_name": "job"},
                    ],
                    "workload_templates": [
                        {"template_name": "spot", "spot_friendly": True},
                        {"template_name": "replicas", "min_non_spot_replicas": 0},
                    ],
                    "workloads": [
                        {"name": "spot-app", "template_name": "spot"},
                        {"name": "replicas-app", "template_name": "replicas"},
                    ],
                })
                self.assertEqual(result["nodeclasses"], [
                    {"name": "memory-class", "memory_extension": memory},
                    {"name": "basic-class", "ami_alias": "al2023@latest"},
                ])
                self.assertEqual(result["nodepools"], [
                    {"name": "cooldown-pool", "disruption_cooldown": "5m"},
                    {"name": "job-pool", "job_nodepool_optimization": job},
                ])
                self.assertEqual(result["workloads"], [
                    {"name": "spot-app", "spot_friendly": True},
                    {"name": "replicas-app", "min_non_spot_replicas": 0},
                ])

    def test_null_templates_leave_concrete_objects_unchanged(self):
        nodeclass = {"name": "plain-class", "memory_extension": None}
        nodepool = {"name": "plain-pool", "disruption_cooldown": None}
        workload = {"name": "plain-app", "spot_friendly": False}
        for cli in self.available_clis():
            with self.subTest(cli=cli):
                result = self.render(cli, {
                    "nodeclass_templates": None, "nodeclasses": [nodeclass],
                    "nodepool_templates": None, "nodepools": [nodepool],
                    "workload_templates": None, "workloads": [workload],
                })
                self.assertEqual(result["nodeclasses"], [nodeclass])
                self.assertEqual(result["nodepools"], [nodepool])
                self.assertEqual(result["workloads"], [workload])

    def test_null_lists_remain_null(self):
        for cli in self.available_clis():
            with self.subTest(cli=cli):
                result = self.render(cli, {"nodeclasses": None, "nodepools": None, "workloads": None})
                self.assertEqual(result, {"nodeclasses": None, "nodepools": None, "workloads": None})


if __name__ == "__main__":
    unittest.main()
