#!/usr/bin/env python3

import argparse
import pathlib
import re
import stat
import sys


RESOURCE_HEADER_RE = re.compile(r'^resource\s+"([^"]+)"\s+"([^"]+)"\s+\{$', re.MULTILINE)
RESOURCE_WITH_ID_RE = re.compile(
    r'# __generated__ by Terraform from "([^"]+)"\s+resource\s+"([^"]+)"\s+"([^"]+)"\s+\{',
    re.MULTILINE,
)
TOP_LEVEL_ATTR_RE = re.compile(r"^  ([a-zA-Z0-9_]+)\s+=\s+(.*)$")

CLUSTER_DEFAULTS = {
    "disable_workload_uploading": "false",
    "only_install_agent": "false",
    "enable_upgrade_agent": "false",
    "enable_upgrade_rebalance_component": "false",
    "enable_upload_config": "true",
    "enable_diversity_instance_type": "false",
    "skip_restore": "false",
    "restore_node_number": "0",
}

WA_DEFAULTS = {
    "storage_class": "\"\"",
    "enable_node_agent": "true",
    "enable_upgrade": "false",
}

NESTED_REPLACEMENTS = {
    "extra_cpu_allocation_mcore = null": "extra_cpu_allocation_mcore = 0",
    "extra_memory_allocation_mib = null": "extra_memory_allocation_mib = 0",
    "extra_cpu_allocation_mcore  = null": "extra_cpu_allocation_mcore  = 0",
    "extra_memory_allocation_mib = null": "extra_memory_allocation_mib = 0",
}


def extract_resource_block(text: str, resource_type: str) -> str | None:
    for match in RESOURCE_HEADER_RE.finditer(text):
        if match.group(1) != resource_type:
            continue
        start = match.end()
        depth = 1
        i = start
        while i < len(text):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    return text[start:i]
            i += 1
        raise ValueError(f"unterminated resource block for {resource_type}")
    return None


def split_top_level_chunks(body: str) -> list[tuple[str | None, str]]:
    chunks: list[tuple[str | None, str]] = []
    current_key: str | None = None
    current_lines: list[str] = []

    for line in body.splitlines(keepends=True):
        match = TOP_LEVEL_ATTR_RE.match(line)
        if match:
            if current_lines:
                chunks.append((current_key, "".join(current_lines)))
            current_key = match.group(1)
            current_lines = [line]
        else:
            if not current_lines and line.strip() == "":
                continue
            current_lines.append(line)

    if current_lines:
        chunks.append((current_key, "".join(current_lines)))

    return chunks


def normalize_nested_values(text: str) -> str:
    for old, new in NESTED_REPLACEMENTS.items():
        text = text.replace(old, new)
    return text


def rewrite_top_level_scalar(key: str, value: str) -> str:
    return f"  {key} = {value}\n"


def transform_cluster_body(body: str) -> list[str]:
    output: list[str] = []
    chunks = split_top_level_chunks(body)

    for key, chunk in chunks:
        if key is None:
            continue

        chunk = normalize_nested_values(chunk)
        line_match = TOP_LEVEL_ATTR_RE.match(chunk.splitlines()[0])
        if not line_match:
            continue
        value = line_match.group(2).strip()

        if key == "cluster_id":
            continue
        if key == "aws_profile":
            output.append(
                "  # Manual verification required: aws_profile is local-only and cannot be recovered from the CloudPilot API.\n"
            )
            output.append(rewrite_top_level_scalar("aws_profile", "var.aws_profile"))
            continue
        if key == "custom_node_role":
            output.append(
                "  # Manual verification required: custom_node_role may not be recoverable from server-side state. Set it explicitly if your original setup used a custom node IAM role for controller PassNodeIAMRole.\n"
            )
            output.append(chunk)
            continue
        if key == "kubeconfig":
            continue
        if key in CLUSTER_DEFAULTS and value == "null":
            output.append(rewrite_top_level_scalar(key, CLUSTER_DEFAULTS[key]))
            continue

        output.append(chunk)

    return output


def transform_wa_body(body: str) -> tuple[list[str], bool]:
    output: list[str] = []
    chunks = split_top_level_chunks(body)

    key_map = {
        "storage_class": "wa_storage_class",
        "enable_node_agent": "wa_enable_node_agent",
        "enable_upgrade": "wa_enable_upgrade",
    }

    for key, chunk in chunks:
        if key is None:
            continue

        line_match = TOP_LEVEL_ATTR_RE.match(chunk.splitlines()[0])
        if not line_match:
            continue
        value = line_match.group(2).strip()

        if key in ("cluster_id", "kubeconfig"):
            continue

        if key in key_map:
            if value == "null":
                value = WA_DEFAULTS[key]
            output.append(rewrite_top_level_scalar(key_map[key], value))
            continue

        output.append(chunk)

    return output, True


def build_module_file(cluster_body: str, wa_body: str | None, source: str) -> str:
    lines = [
        "# Generated from generated.tf by scripts/generated_to_module.py.\n",
        "# Review this file before committing it.\n",
        "# Manual validation still required for fields the CloudPilot API cannot fully recover.\n",
        "# In particular, verify aws_profile and custom_node_role against your original Terraform/AWS setup.\n",
        "\n",
        "module \"cloudpilotai_eks\" {\n",
        f"  source = \"{source}\"\n",
        "\n",
    ]

    lines.extend(transform_cluster_body(cluster_body))

    if wa_body is None:
        lines.append("\n")
        lines.append(rewrite_top_level_scalar("enable_workload_autoscaler", "false"))
    else:
        wa_lines, _ = transform_wa_body(wa_body)
        lines.append("\n")
        lines.append(rewrite_top_level_scalar("enable_workload_autoscaler", "true"))
        lines.extend(wa_lines)

    lines.append("}\n")
    return "".join(lines)


def extract_import_id(text: str, resource_type: str) -> str:
    for match in RESOURCE_WITH_ID_RE.finditer(text):
        import_id, matched_type, _ = match.groups()
        if matched_type == resource_type:
            return import_id
    raise ValueError(f'import ID not found for resource type "{resource_type}"')


def build_import_script(cluster_id: str, include_wa: bool) -> str:
    lines = [
        "#!/usr/bin/env bash\n",
        "set -euo pipefail\n",
        "\n",
        f"terraform import 'module.cloudpilotai_eks.cloudpilotai_eks_cluster.this' '{cluster_id}'\n",
    ]
    if include_wa:
        lines.append(
            f"terraform import 'module.cloudpilotai_eks.cloudpilotai_workload_autoscaler.this[0]' '{cluster_id}'\n"
        )
    return "".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Convert Terraform generated provider resources into terraform-cloudpilotai-eks module config."
    )
    parser.add_argument("--input", default="generated.tf", help="Path to the generated.tf file")
    parser.add_argument(
        "--output",
        default="module.generated.tf",
        help="Path to write the generated module configuration",
    )
    parser.add_argument(
        "--import-script",
        default="import-module.sh",
        help="Path to write the helper import script",
    )
    parser.add_argument(
        "--module-source",
        default="cloudpilot-ai/eks/cloudpilotai",
        help="Module source expression to use in the generated module block",
    )
    args = parser.parse_args()

    input_path = pathlib.Path(args.input)
    if not input_path.exists():
        print(f"input file not found: {input_path}", file=sys.stderr)
        return 1

    text = input_path.read_text()
    cluster_body = extract_resource_block(text, "cloudpilotai_eks_cluster")
    if cluster_body is None:
        print("generated.tf does not contain resource \"cloudpilotai_eks_cluster\"", file=sys.stderr)
        return 1

    wa_body = extract_resource_block(text, "cloudpilotai_workload_autoscaler")
    cluster_id = extract_import_id(text, "cloudpilotai_eks_cluster")

    module_text = build_module_file(cluster_body, wa_body, args.module_source)
    output_path = pathlib.Path(args.output)
    output_path.write_text(module_text)

    import_script = build_import_script(cluster_id, wa_body is not None)
    import_path = pathlib.Path(args.import_script)
    import_path.write_text(import_script)
    import_path.chmod(import_path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)

    print(f"wrote module configuration to {output_path}")
    print(f"wrote helper import script to {import_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
