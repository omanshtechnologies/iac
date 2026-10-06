#!/bin/bash
# Shared helpers (rendered by Terraform, installed at /usr/local/bin/runner-common.sh)

retry() { # retry <attempts> <cmd...>
  local n=$1; shift
  local i
  for i in $(seq 1 "$n"); do
    "$@" && return 0
    sleep $((i * 3))
  done
  return 1
}

# Reads the GitHub token from Secret Manager using the VM's service account.
# Nothing is written to disk; the token only lives in a shell variable.
fetch_pat() {
  local access
  access=$(curl -sf -H 'Metadata-Flavor: Google' \
    'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token' | jq -r .access_token) || return 1
  curl -sf -H "Authorization: Bearer $access" \
    'https://secretmanager.googleapis.com/v1/projects/${project_id}/secrets/${secret_id}/versions/latest:access' \
    | jq -r .payload.data | base64 -d
}

# github_token <registration|remove>
github_token() {
  local pat
  pat=$(fetch_pat) || return 1
  curl -sf -X POST \
    -H "Authorization: Bearer $pat" \
    -H 'Accept: application/vnd.github+json' \
    "https://api.github.com/${github_api}/actions/runners/$1-token" | jq -r .token
}
