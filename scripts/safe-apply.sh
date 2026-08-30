#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${REPO_DIR}/terraform"

export AWS_PROFILE="${AWS_PROFILE:-terraform}"

STAMP="$(date +%Y%m%d-%H%M%S)"
PLAN="${1:-${TF_DIR}/safe-${STAMP}.tfplan}"
JSON="${PLAN}.json"

echo "========== TERRAFORM FORMAT CHECK =========="

terraform -chdir="$TF_DIR" fmt -check

echo
echo "========== TERRAFORM VALIDATE =========="

terraform -chdir="$TF_DIR" validate

echo
echo "========== CREATE SAVED PLAN =========="

terraform -chdir="$TF_DIR" plan \
  -lock-timeout=5m \
  -out="$PLAN"

terraform -chdir="$TF_DIR" show \
  -json "$PLAN" > "$JSON"

echo
echo "========== PLAN SUMMARY =========="

jq -r '
  [.resource_changes[]?.change.actions] |
  {
    create: map(select(. == ["create"])) | length,
    update: map(select(. == ["update"])) | length,
    delete: map(select(. == ["delete"])) | length,
    replace: map(select(
      (. == ["delete","create"]) or
      (. == ["create","delete"])
    )) | length
  }
' "$JSON"

DELETE_COUNT=$(jq '
  [
    .resource_changes[]?
    | select(
        (.change.actions | index("delete")) != null
      )
  ]
  | length
' "$JSON")

echo
echo "========== RESOURCES TO CHANGE =========="

jq -r '
  .resource_changes[]?
  | select(.change.actions != ["no-op"])
  | "\(.address) -> \(.change.actions | join(","))"
' "$JSON"

if [ "$DELETE_COUNT" -ne 0 ]; then
  echo
  echo "============================================"
  echo "BLOCKED: DELETE OR REPLACE DETECTED"
  echo "============================================"

  jq -r '
    .resource_changes[]?
    | select(
        (.change.actions | index("delete")) != null
      )
    | "\(.address) -> \(.change.actions | join(","))"
  ' "$JSON"

  echo
  echo "NO APPLY WAS PERFORMED"
  exit 50
fi

echo
echo "============================================"
echo "SAFE PLAN: ZERO DELETE/REPLACE ACTIONS"
echo "============================================"
echo
echo "Saved plan:"
echo "$PLAN"
echo

read -r -p "Type APPLY to apply this exact saved plan: " CONFIRM

if [ "$CONFIRM" != "APPLY" ]; then
  echo
  echo "Cancelled. NO APPLY WAS PERFORMED."
  exit 0
fi

echo
echo "========== APPLY SAVED PLAN =========="

terraform -chdir="$TF_DIR" apply "$PLAN"

echo
echo "========== COMPLETE =========="
