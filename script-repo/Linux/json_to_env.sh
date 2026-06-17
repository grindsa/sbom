#!/usr/bin/env bash

json_to_env_main() {
  local old_shell_opts
  old_shell_opts="$(set +o)"

  # When sourced, avoid leaking strict mode into the caller shell.
  set -euo pipefail
  trap 'eval "$old_shell_opts"; trap - RETURN' RETURN

  if [[ $# -ne 1 ]]; then
    echo "Usage: source ./json_to_env.sh <json-file>" >&2
    return 1
  fi

  local json_file
  json_file="$1"

  if [[ ! -f "$json_file" ]]; then
    echo "Error: file not found: $json_file" >&2
    return 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required" >&2
    return 1
  fi

  b64_decode() {
    if base64 --help 2>/dev/null | grep -q -- "--decode"; then
      base64 --decode
    else
      base64 -D
    fi
  }

  while IFS=$'\t' read -r key value_b64; do
    if [[ ! "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      echo "Skipping invalid env var name: $key" >&2
      continue
    fi

    value="$(printf '%s' "$value_b64" | b64_decode)"
    printf -v "$key" '%s' "$value"
    export "$key"
  done < <(
    jq -r '
      to_entries[]
      | [.key, (.value | tostring | @base64)]
      | @tsv
    ' "$json_file"
  )

  echo "Environment variables loaded from: $json_file"
}

if ! json_to_env_main "$@"; then
  return 1 2>/dev/null || exit 1
fi
