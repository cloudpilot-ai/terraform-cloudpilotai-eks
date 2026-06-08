#!/usr/bin/env python3

import argparse
import pathlib
import re
import stat
import sys


RESOURCE_HEADER_RE = re.compile(r'^resource\s+"([^"]+)"\s+"([^"]+)"\s+\{$', re.MULTILINE)
RESOURCE_WITH_ID_RE = re.compile(
    r'# __generated__ by (?:Terraform|OpenTofu) from "([^"]+)"\s+resource\s+"([^"]+)"\s+"([^"]+)"\s+\{',
    re.MULTILINE,
)
TOP_LEVEL_ATTR_RE = re.compile(r"^  ([a-zA-Z0-9_]+)\s+=\s+(.*)$")

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

def rewrite_top_level_scalar(key: str, value: str) -> str:
    return f"  {key} = {value}\n"


def indent_block(text: str, prefix: str) -> str:
    return "".join(prefix + line if line.strip() else line for line in text.splitlines(keepends=True))


def has_top_level_key(body: str, key: str) -> bool:
    return any(chunk_key == key for chunk_key, _ in split_top_level_chunks(body))


def strip_removed_cluster_setting_fields(chunk: str) -> str:
    kept_lines = [
        line for line in chunk.splitlines(keepends=True)
        if not re.match(r"^\s+maintenance_enabled\s+=", line)
    ]

    non_empty_inner_lines = [
        line for line in kept_lines[1:-1]
        if line.strip()
    ]
    if kept_lines and kept_lines[0].lstrip().startswith("cluster_setting") and not non_empty_inner_lines:
        return ""
    return "".join(kept_lines)


def normalize_cluster_setting_command_nulls(chunk: str) -> str:
    return re.sub(
        r"^(\s+(?:pre_run_command|post_run_command)\s+=\s+)null$",
        r'\1""',
        chunk,
        flags=re.MULTILINE,
    )


def strip_removed_block_device_fields(chunk: str) -> str:
    removed_keys = ("delete_on_termination", "iops", "kms_key_id", "snapshot_id", "throughput")
    kept_lines = [
        line for line in chunk.splitlines(keepends=True)
        if not any(re.match(rf"^\s+{key}\s+=", line) for key in removed_keys)
    ]
    return "".join(kept_lines)


def transform_cluster_body(body: str) -> list[str]:
    output: list[str] = []
    chunks = split_top_level_chunks(body)

    for key, chunk in chunks:
        if key is None:
            continue

        line_match = TOP_LEVEL_ATTR_RE.match(chunk.splitlines()[0])
        if not line_match:
            continue
        value = line_match.group(2).strip()

        if key == "cluster_id":
            output.append(rewrite_top_level_scalar("cluster_id", "var.cluster_id"))
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
        if key == "enable_diversity_instance_type":
            continue
        if key == "enable_upload_config":
            continue
        if key == "cluster_setting":
            chunk = strip_removed_cluster_setting_fields(chunk)
            if chunk == "":
                continue
            chunk = normalize_cluster_setting_command_nulls(chunk)
        chunk = strip_removed_block_device_fields(chunk)

        output.append(chunk)

    return output


def transform_cluster_setting_body(body: str | None) -> str | None:
    if body is None:
        return None

    attrs: list[str] = []
    for key, chunk in split_top_level_chunks(body):
        if key in (None, "cluster_id", "maintenance_enabled"):
            continue
        if key in ("pre_run_command", "post_run_command"):
            line_match = TOP_LEVEL_ATTR_RE.match(chunk.splitlines()[0])
            if line_match and line_match.group(2).strip() == "null":
                chunk = rewrite_top_level_scalar(key, '""')
        attrs.append(indent_block(chunk, "  "))

    if not attrs:
        return None

    return "".join([
        "  cluster_setting = {\n",
        *attrs,
        "  }\n",
    ])


def transform_wa_body(body: str) -> tuple[list[str], bool]:
    output: list[str] = []
    chunks = split_top_level_chunks(body)

    key_map = {
        "storage_class": "wa_storage_class",
        "enable_node_agent": "wa_enable_node_agent",
        "enable_new_workloads_proactive_update": "wa_enable_new_workloads_proactive_update",
        "limiter_quota_per_window": "wa_limiter_quota_per_window",
        "limiter_burst": "wa_limiter_burst",
        "limiter_window_seconds": "wa_limiter_window_seconds",
        "enable_preempted_pod_gc": "wa_enable_preempted_pod_gc",
        "preempted_pod_gc_ttl": "wa_preempted_pod_gc_ttl",
        "enable_initial_optimization_data_window_check": "wa_enable_initial_optimization_data_window_check",
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
            output.append(rewrite_top_level_scalar(key_map[key], value))
            continue

        output.append(chunk)

    return output, True


def build_module_file(
    cluster_body: str,
    cluster_setting_body: str | None,
    wa_body: str | None,
    source: str,
) -> str:
    lines = [
        "# Generated from generated.tf by scripts/generated_to_module.py.\n",
        "# Review this file before committing it.\n",
        "# Manual validation still required for fields the CloudPilot API cannot fully recover.\n",
        "# In particular, verify aws_profile, aws_assume_role, and custom_node_role against your original Terraform/AWS setup.\n",
        "\n",
        "module \"cloudpilotai_eks\" {\n",
        f"  source = \"{source}\"\n",
        "\n",
    ]

    lines.extend(transform_cluster_body(cluster_body))
    if not has_top_level_key(cluster_body, "cluster_setting"):
        legacy_cluster_setting = transform_cluster_setting_body(cluster_setting_body)
        if legacy_cluster_setting is not None:
            lines.append(legacy_cluster_setting)

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
    cluster_setting_body = extract_resource_block(text, "cloudpilotai_cluster_setting")
    cluster_id = extract_import_id(text, "cloudpilotai_eks_cluster")

    module_text = build_module_file(cluster_body, cluster_setting_body, wa_body, args.module_source)
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
