#!/usr/bin/env sh
# Shared FinOps helpers (dry-run / confirm). Sourced by finops-cleanup.sh and prune scripts.

# ---------------------------------------------------------------------------
# dry_run_exec COMMAND [ARGS...]
#   In dry-run mode  → prints the command prefixed with [DRY-RUN].
#   In live mode     → executes the command.
# ---------------------------------------------------------------------------
dry_run_exec() {
  if [ "${dry_run:-true}" = "true" ]; then
    echo "[DRY-RUN] $*"
  else
    "$@"
  fi
}

# ---------------------------------------------------------------------------
# require_confirm
#   Aborts if dry_run=false and confirm != yes.
#   Call this once after parsing args, before any destructive operation.
# ---------------------------------------------------------------------------
require_confirm() {
  if [ "${dry_run:-true}" = "false" ] && [ "${confirm:-}" != "yes" ]; then
    echo "ERROR: dry_run=false requires confirm=yes to prevent accidents." >&2
    echo "       Re-run with: dry_run=false confirm=yes" >&2
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# section TITLE
#   Prints a visible section separator.
# ---------------------------------------------------------------------------
section() {
  echo ""
  echo "=== $* ==="
}