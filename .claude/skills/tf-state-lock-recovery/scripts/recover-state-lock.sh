#!/usr/bin/env bash
# Recover from a stale Terraform S3 native lockfile (use_lockfile).
# Downloads current remote state to last.terraform.tfstate, diffs vs local,
# and deletes the .tflock only when states are identical (or --force-unlock).
#
# Exit codes:
#   0 — lock deleted (states matched, or --force-unlock)
#   1 — usage / AWS / config error
#   2 — states differ (lock kept)
#   3 — no local baseline to compare (lock kept)

set -euo pipefail

ENV_DIR="."
FORCE_UNLOCK=0

usage() {
  cat <<'EOF'
Usage: recover-state-lock.sh [--env-dir DIR] [--force-unlock]

Downloads s3://$bucket/$key (current object, no version id) to
last.terraform.tfstate in DIR, compares with local terraform.tfstate
(or a prior last.terraform.tfstate), and deletes $key.tflock only when
the states are identical.

--force-unlock  Delete the lock after download even without a matching
                baseline. Use only after reviewing lock info and confirming
                no other apply is running.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env-dir)
      ENV_DIR="${2:?--env-dir requires a path}"
      shift 2
      ;;
    --force-unlock)
      FORCE_UNLOCK=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! command -v aws >/dev/null 2>&1; then
  echo "error: aws CLI is required" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required" >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "error: python3 is required" >&2
  exit 1
fi

ENV_DIR="$(cd "$ENV_DIR" && pwd)"
BACKEND_HCL="$ENV_DIR/backend.hcl"
BACKEND_TF="$ENV_DIR/backend.tf"
REMOTE_STATE="$ENV_DIR/last.terraform.tfstate"
LOCAL_STATE="$ENV_DIR/terraform.tfstate"
PRIOR_REMOTE="$ENV_DIR/last.terraform.tfstate.prev"
LOCK_JSON="$(mktemp)"
DOWNLOAD_TMP="$(mktemp)"
NORMALIZED_A="$(mktemp)"
NORMALIZED_B="$(mktemp)"

cleanup() {
  rm -f "$LOCK_JSON" "$DOWNLOAD_TMP" "$NORMALIZED_A" "$NORMALIZED_B"
}
trap cleanup EXIT

if [[ ! -f "$BACKEND_HCL" ]]; then
  echo "error: missing $BACKEND_HCL (copy from backend.hcl.example and set bucket)" >&2
  exit 1
fi
if [[ ! -f "$BACKEND_TF" ]]; then
  echo "error: missing $BACKEND_TF" >&2
  exit 1
fi

extract_hcl_string() {
  local file="$1"
  local key="$2"
  local line
  line="$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "$file" | head -n1 || true)"
  if [[ -z "$line" ]]; then
    return 1
  fi
  python3 -c 'import re,sys; m=re.search(r"=\s*\"([^\"]+)\"", sys.argv[1]); sys.exit(1) if not m else print(m.group(1))' "$line"
}

print_lock_info() {
  if aws s3api head-object --bucket "$BUCKET" --key "$LOCK_KEY" --region "$REGION" >/dev/null 2>&1; then
    aws s3 cp "s3://$BUCKET/$LOCK_KEY" "$LOCK_JSON" --region "$REGION" >/dev/null
    echo "Current lock info:"
    jq . "$LOCK_JSON" 2>/dev/null || cat "$LOCK_JSON"
  else
    echo "No lock object present at s3://$BUCKET/$LOCK_KEY"
  fi
}

delete_lock() {
  if aws s3api head-object --bucket "$BUCKET" --key "$LOCK_KEY" --region "$REGION" >/dev/null 2>&1; then
    echo "Deleting stale lock s3://$BUCKET/$LOCK_KEY"
    aws s3api delete-object \
      --bucket "$BUCKET" \
      --key "$LOCK_KEY" \
      --region "$REGION" >/dev/null
    echo "Lock deleted."
  else
    echo "No lock object present (already cleared)."
  fi
}

BUCKET="$(extract_hcl_string "$BACKEND_HCL" bucket)" || {
  echo "error: could not read bucket from $BACKEND_HCL" >&2
  exit 1
}
REGION="$(extract_hcl_string "$BACKEND_TF" region || true)"
if [[ -z "${REGION:-}" ]]; then
  REGION="$(extract_hcl_string "$BACKEND_HCL" region || true)"
fi
if [[ -z "${REGION:-}" ]]; then
  REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
fi
if [[ -z "${REGION:-}" ]]; then
  echo "error: could not determine AWS region (backend.tf / backend.hcl / AWS_REGION)" >&2
  exit 1
fi
KEY="$(extract_hcl_string "$BACKEND_TF" key)" || {
  echo "error: could not read key from $BACKEND_TF" >&2
  exit 1
}
LOCK_KEY="${KEY}.tflock"

echo "Backend: s3://$BUCKET/$KEY (region=$REGION)"
echo "Lock:    s3://$BUCKET/$LOCK_KEY"

# Preserve prior last.terraform.tfstate as comparison fallback before overwrite.
if [[ -f "$REMOTE_STATE" ]]; then
  cp "$REMOTE_STATE" "$PRIOR_REMOTE"
fi

echo "Downloading current state (no version id) → $REMOTE_STATE"
aws s3api get-object \
  --bucket "$BUCKET" \
  --key "$KEY" \
  --region "$REGION" \
  "$DOWNLOAD_TMP" >/dev/null
mv "$DOWNLOAD_TMP" "$REMOTE_STATE"
DOWNLOAD_TMP="$(mktemp)"

if ! jq -e . "$REMOTE_STATE" >/dev/null 2>&1; then
  echo "error: downloaded state is not valid JSON: $REMOTE_STATE" >&2
  exit 1
fi

BASELINE=""
if [[ -f "$LOCAL_STATE" ]]; then
  BASELINE="$LOCAL_STATE"
  echo "Comparing against local $LOCAL_STATE"
elif [[ -f "$PRIOR_REMOTE" ]]; then
  BASELINE="$PRIOR_REMOTE"
  echo "Comparing against prior $PRIOR_REMOTE (no terraform.tfstate present)"
fi

if [[ -z "$BASELINE" ]]; then
  echo "No local baseline found (need terraform.tfstate or a prior last.terraform.tfstate)."
  echo "Downloaded remote state to: $REMOTE_STATE"
  print_lock_info
  if [[ "$FORCE_UNLOCK" -eq 1 ]]; then
    echo "--force-unlock set: deleting lock without a local comparison baseline."
    delete_lock
    rm -f "$PRIOR_REMOTE"
    echo
    echo "Stale lock removed (--force-unlock). You can now safely run the terraform commands again."
    exit 0
  fi
  echo "Refusing to delete the lock without a local comparison baseline."
  echo "Re-run with --force-unlock only after confirming no other apply is running."
  exit 3
fi

if ! jq -e . "$BASELINE" >/dev/null 2>&1; then
  echo "error: local baseline is not valid JSON: $BASELINE" >&2
  exit 1
fi

# Stable key order; full document must match (serial, lineage, resources).
jq -S . "$BASELINE" >"$NORMALIZED_A"
jq -S . "$REMOTE_STATE" >"$NORMALIZED_B"

if ! cmp -s "$NORMALIZED_A" "$NORMALIZED_B"; then
  echo
  echo "States DIFFER — keeping the lock. Diff (local baseline vs last.terraform.tfstate):"
  echo "----------------------------------------------------------------"
  if command -v diff >/dev/null 2>&1; then
    diff -u "$NORMALIZED_A" "$NORMALIZED_B" || true
  else
    echo "local  lineage=$(jq -r '.lineage // empty' "$BASELINE") serial=$(jq -r '.serial // empty' "$BASELINE")"
    echo "remote lineage=$(jq -r '.lineage // empty' "$REMOTE_STATE") serial=$(jq -r '.serial // empty' "$REMOTE_STATE")"
  fi
  echo "----------------------------------------------------------------"
  echo "Remote snapshot saved at: $REMOTE_STATE"
  if [[ "$FORCE_UNLOCK" -eq 1 ]]; then
    echo "--force-unlock set despite diff: deleting lock."
    delete_lock
    rm -f "$PRIOR_REMOTE"
    echo
    echo "Stale lock removed (--force-unlock). You can now safely run the terraform commands again."
    exit 0
  fi
  exit 2
fi

echo "States match (lineage=$(jq -r .lineage "$REMOTE_STATE") serial=$(jq -r .serial "$REMOTE_STATE"))."
delete_lock
rm -f "$PRIOR_REMOTE"

echo
echo "States match. Stale lock removed. You can now safely run the terraform commands again."
exit 0
