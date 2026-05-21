#!/usr/bin/env bash
# cleanup-pipelines.sh — Delete old GitLab pipelines via the API
#
# Usage:
#   GITLAB_TOKEN=<token> GITLAB_PROJECT_ID=<id> ./cleanup-pipelines.sh [options]
#
# Options:
#   --keep <n>          Keep the N most recent pipelines (default: 20)
#   --status <status>   Only delete pipelines with this status
#                       Values: failed, canceled, skipped, success, manual
#                       Default: all statuses except running/pending
#   --dry-run           Print what would be deleted without deleting
#   --gitlab-url <url>  GitLab base URL (default: https://gitlab.com)
#
# Required environment variables:
#   GITLAB_TOKEN        Personal access token with api scope
#   GITLAB_PROJECT_ID   Numeric project ID (found in project Settings > General)
#
# Examples:
#   # Delete all failed pipelines, keep the 10 most recent overall
#   GITLAB_TOKEN=xxx GITLAB_PROJECT_ID=123 ./cleanup-pipelines.sh --keep 10 --status failed
#
#   # Dry-run: see what would be deleted
#   GITLAB_TOKEN=xxx GITLAB_PROJECT_ID=123 ./cleanup-pipelines.sh --dry-run
#
set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
KEEP=20
STATUS_FILTER=""
DRY_RUN=false
GITLAB_URL="${GITLAB_URL:-https://gitlab.com}"
PER_PAGE=100

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep)        KEEP="$2";          shift 2 ;;
    --status)      STATUS_FILTER="$2"; shift 2 ;;
    --dry-run)     DRY_RUN=true;       shift   ;;
    --gitlab-url)  GITLAB_URL="$2";    shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# ── Validation ────────────────────────────────────────────────────────────────
if [[ -z "${GITLAB_TOKEN:-}" ]]; then
  echo "Error: GITLAB_TOKEN is not set." >&2
  exit 1
fi

if [[ -z "${GITLAB_PROJECT_ID:-}" ]]; then
  echo "Error: GITLAB_PROJECT_ID is not set." >&2
  exit 1
fi

API="${GITLAB_URL}/api/v4/projects/${GITLAB_PROJECT_ID}/pipelines"
AUTH_HEADER="PRIVATE-TOKEN: ${GITLAB_TOKEN}"

# ── Fetch pipeline IDs ────────────────────────────────────────────────────────
echo "Fetching pipelines from ${GITLAB_URL} (project ${GITLAB_PROJECT_ID})..."

pipeline_ids=()
page=1

while true; do
  url="${API}?per_page=${PER_PAGE}&page=${page}&order_by=id&sort=desc"
  [[ -n "$STATUS_FILTER" ]] && url="${url}&status=${STATUS_FILTER}"

  response=$(curl --silent --fail --header "$AUTH_HEADER" "$url")

  # Extract IDs from JSON array (requires jq)
  if ! command -v jq &>/dev/null; then
    echo "Error: 'jq' is required but not installed." >&2
    exit 1
  fi

  ids=$(echo "$response" | jq -r '.[].id')

  [[ -z "$ids" ]] && break

  while IFS= read -r id; do
    pipeline_ids+=("$id")
  done <<< "$ids"

  count=$(echo "$response" | jq 'length')
  [[ "$count" -lt "$PER_PAGE" ]] && break

  ((page++))
done

total=${#pipeline_ids[@]}
echo "Found ${total} pipeline(s)${STATUS_FILTER:+ with status '${STATUS_FILTER}'}."

if [[ "$total" -le "$KEEP" ]]; then
  echo "Nothing to delete — total (${total}) ≤ keep threshold (${KEEP})."
  exit 0
fi

# ── Delete pipelines older than the Nth most recent ──────────────────────────
# pipeline_ids is already sorted newest→oldest (sort=desc)
to_delete=("${pipeline_ids[@]:$KEEP}")
delete_count=${#to_delete[@]}

echo "Will delete ${delete_count} pipeline(s) (keeping the ${KEEP} most recent)."
$DRY_RUN && echo "[DRY RUN] No pipelines will actually be deleted."

deleted=0
failed=0

for id in "${to_delete[@]}"; do
  if $DRY_RUN; then
    echo "  [dry-run] Would delete pipeline #${id}"
  else
    http_code=$(curl --silent --output /dev/null --write-out "%{http_code}" \
      --request DELETE \
      --header "$AUTH_HEADER" \
      "${API}/${id}")

    if [[ "$http_code" == "204" ]]; then
      echo "  Deleted pipeline #${id}"
      ((deleted++))
    else
      echo "  Failed to delete pipeline #${id} (HTTP ${http_code})" >&2
      ((failed++))
    fi
  fi
done

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
if $DRY_RUN; then
  echo "Dry run complete. ${delete_count} pipeline(s) would be deleted."
else
  echo "Done. Deleted: ${deleted}, Failed: ${failed}."
fi
