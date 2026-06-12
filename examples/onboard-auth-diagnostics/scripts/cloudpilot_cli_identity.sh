#!/usr/bin/env bash

set -euo pipefail

cluster_name="${1:?cluster_name is required}"
region="${2:?region is required}"
profile="${3:-}"
role_arn="${4:?aws_assume_role_arn is required}"
session_name="${5:?aws_assume_role_session_name is required}"
source_mode="ambient-default-chain"
source_arn=""

if [[ "$profile" == "__CLOUDPILOT_EMPTY_PROFILE__" ]]; then
  profile=""
fi

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

log() {
  printf '%s\n' "$*" >&2
}

print_env_hint() {
  local name="$1"
  local value="${!name:-}"
  if [[ -z "$value" ]]; then
    log "  ${name}=<unset>"
    return
  fi

  case "$name" in
    AWS_PROFILE|AWS_REGION|AWS_DEFAULT_REGION|AWS_SHARED_CREDENTIALS_FILE|AWS_CONFIG_FILE|AWS_ROLE_ARN|AWS_WEB_IDENTITY_TOKEN_FILE)
      log "  ${name}=${value}"
      ;;
    AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY|AWS_SESSION_TOKEN)
      log "  ${name}=<set, ${#value} chars>"
      ;;
    *)
      log "  ${name}=<set>"
      ;;
  esac
}

print_env_hints() {
  log "AWS environment hints:"
  print_env_hint AWS_PROFILE
  print_env_hint AWS_ACCESS_KEY_ID
  print_env_hint AWS_SECRET_ACCESS_KEY
  print_env_hint AWS_SESSION_TOKEN
  print_env_hint AWS_REGION
  print_env_hint AWS_DEFAULT_REGION
  print_env_hint AWS_SHARED_CREDENTIALS_FILE
  print_env_hint AWS_CONFIG_FILE
  print_env_hint AWS_ROLE_ARN
  print_env_hint AWS_WEB_IDENTITY_TOKEN_FILE
}

print_config_list() {
  local output
  local -a cmd=(aws configure list)
  if [[ -n "$profile" ]]; then
    cmd+=(--profile "$profile")
  fi

  if output="$("${cmd[@]}" 2>&1)"; then
    while IFS= read -r line; do
      log "  ${line}"
    done <<<"$output"
  else
    log "  failed to run: ${cmd[*]}"
    while IFS= read -r line; do
      log "  ${line}"
    done <<<"$output"
  fi
}

stage_hint() {
  local stage="$1"
  case "$stage" in
    source_identity)
      log "Interpretation: the CloudPilot-style AWS CLI path failed before sts assume-role. The source credential chain is not usable."
      ;;
    assume_role)
      log "Interpretation: the source credential chain worked, but sts assume-role for the target role failed."
      if [[ -n "$source_arn" ]]; then
        log "Resolved source identity before failure: ${source_arn}"
      fi
      ;;
    assumed_identity)
      log "Interpretation: sts assume-role returned temporary credentials, but they were not accepted by AWS."
      if [[ -n "$source_arn" ]]; then
        log "Resolved source identity before failure: ${source_arn}"
      fi
      ;;
    describe_cluster)
      log "Interpretation: assume-role succeeded, but the assumed role could not describe the target EKS cluster."
      if [[ -n "$source_arn" ]]; then
        log "Resolved source identity before failure: ${source_arn}"
      fi
      ;;
    get_token)
      log "Interpretation: assume-role succeeded, but the assumed role could not generate an EKS auth token for the target cluster."
      log "This is the closest AWS-CLI-only check to the later kubeconfig exec-auth path used by kubectl and helm."
      if [[ -n "$source_arn" ]]; then
        log "Resolved source identity before failure: ${source_arn}"
      fi
      ;;
  esac
}

fail_stage() {
  local stage="$1"
  local command="$2"
  local output="$3"

  log "CloudPilot auth diagnostics failed."
  log "Stage: ${stage}"
  log "Source mode: ${source_mode}"
  log "Cluster name: ${cluster_name}"
  log "Region: ${region}"
  log "Role ARN: ${role_arn}"
  log "Session name: ${session_name}"
  log "Command: ${command}"
  log ""
  print_env_hints
  log ""
  log "aws configure list:"
  print_config_list
  log ""
  stage_hint "$stage"
  log ""
  log "AWS CLI error:"
  while IFS= read -r line; do
    log "  ${line}"
  done <<<"$output"
  exit 1
}

run_aws_text() {
  local stage="$1"
  local query="$2"
  shift 2

  local output
  if ! output="$(aws "$@" --query "$query" --output text 2>&1)"; then
    fail_stage "$stage" "aws $* --query ${query} --output text" "$output"
  fi
  printf '%s' "$output"
}

run_aws_text_with_env() {
  local stage="$1"
  local query="$2"
  shift 2

  local -a env_args=()
  while [[ $# -gt 0 && "$1" == *=* ]]; do
    env_args+=("$1")
    shift
  done

  local output
  if ! output="$(env "${env_args[@]}" aws "$@" --query "$query" --output text 2>&1)"; then
    fail_stage "$stage" "env [assumed-role-creds] aws $* --query ${query} --output text" "$output"
  fi
  printf '%s' "$output"
}

if [[ -n "$profile" ]]; then
  source_mode="profile:${profile}"
  source_arn="$(run_aws_text source_identity 'Arn' sts get-caller-identity --profile "$profile")"
  source_account="$(run_aws_text source_identity 'Account' sts get-caller-identity --profile "$profile")"
  assume_role_fields="$(run_aws_text assume_role 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' sts assume-role --role-arn "$role_arn" --role-session-name "$session_name" --profile "$profile")"
else
  if [[ -n "${AWS_PROFILE:-}" ]]; then
    source_mode="ambient-env-profile:${AWS_PROFILE}"
  elif [[ -n "${AWS_WEB_IDENTITY_TOKEN_FILE:-}" || -n "${AWS_ROLE_ARN:-}" ]]; then
    source_mode="ambient-web-identity"
  elif [[ -n "${AWS_ACCESS_KEY_ID:-}" || -n "${AWS_SESSION_TOKEN:-}" ]]; then
    source_mode="ambient-env-credentials"
  else
    source_mode="ambient-default-chain"
  fi

  source_arn="$(run_aws_text source_identity 'Arn' sts get-caller-identity)"
  source_account="$(run_aws_text source_identity 'Account' sts get-caller-identity)"
  assume_role_fields="$(run_aws_text assume_role 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' sts assume-role --role-arn "$role_arn" --role-session-name "$session_name")"
fi

IFS=$'\t' read -r access_key_id secret_access_key session_token <<<"$assume_role_fields"

assumed_arn="$(run_aws_text_with_env assumed_identity 'Arn' \
  "AWS_ACCESS_KEY_ID=$access_key_id" \
  "AWS_SECRET_ACCESS_KEY=$secret_access_key" \
  "AWS_SESSION_TOKEN=$session_token" \
  sts get-caller-identity)"

assumed_account="$(run_aws_text_with_env assumed_identity 'Account' \
  "AWS_ACCESS_KEY_ID=$access_key_id" \
  "AWS_SECRET_ACCESS_KEY=$secret_access_key" \
  "AWS_SESSION_TOKEN=$session_token" \
  sts get-caller-identity)"

cluster_arn="$(run_aws_text_with_env describe_cluster 'cluster.arn' \
  "AWS_ACCESS_KEY_ID=$access_key_id" \
  "AWS_SECRET_ACCESS_KEY=$secret_access_key" \
  "AWS_SESSION_TOKEN=$session_token" \
  eks describe-cluster --name "$cluster_name" --region "$region")"

token_expiration="$(run_aws_text_with_env get_token 'status.expirationTimestamp' \
  "AWS_ACCESS_KEY_ID=$access_key_id" \
  "AWS_SECRET_ACCESS_KEY=$secret_access_key" \
  "AWS_SESSION_TOKEN=$session_token" \
  eks get-token --cluster-name "$cluster_name" --region "$region")"

printf '{"source_mode":"%s","source_arn":"%s","source_account":"%s","assumed_arn":"%s","assumed_account":"%s","cluster_arn":"%s","token_expiration":"%s","role_session_name":"%s"}\n' \
  "$(json_escape "$source_mode")" \
  "$(json_escape "$source_arn")" \
  "$(json_escape "$source_account")" \
  "$(json_escape "$assumed_arn")" \
  "$(json_escape "$assumed_account")" \
  "$(json_escape "$cluster_arn")" \
  "$(json_escape "$token_expiration")" \
  "$(json_escape "$session_name")"
