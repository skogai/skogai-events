#!/usr/bin/env bash
# SessionStart: write the current state files if `write_state` is on (see
# write-state.sh), then log it.
set -euo pipefail
. "$(dirname "$0")/../guard.sh"

here=$(dirname "$0")
input=$(cat)
cwd=$(jq -r '.cwd' <<<"$input")

action=
if root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null); then
  . "$here/../settings.sh"
  if skogai_on write_state; then
    "$here/../write-state.sh" "$root" "$SKOGAI_STATE"
    action="wrote state"
  fi
fi
exec "$here/../append-json.sh" "$action" <<<"$input"
