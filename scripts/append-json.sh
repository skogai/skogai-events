#!/usr/bin/env bash
# Appends one row to the event log for an event we acted upon.
# Skips the row when the plugin is off (see guard.sh) or the mod settings
# (see settings.sh) leave the event out of `events`.
# Usage: <hook stdin json> | append-json.sh [what we did]
set -euo pipefail
. "$(dirname "$0")/guard.sh"

input=$(cat)
# Both fields in one jq call: each call costs ~70 ms when jq is a mise shim.
IFS=$'\x1f' read -r event cwd < <(jq -r '[.hook_event_name // "", .cwd // ""] | join("\u001f")' <<<"$input")
cwd=${cwd:-$PWD}
root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || echo "$cwd")
. "$(dirname "$0")/settings.sh"
skogai_logs "$event" || exit 0
log=$SKOGAI_LOG
mkdir -p "$(dirname "$log")"

# Hooks can fire in parallel (PreToolUse for parallel tool calls), so hold a
# lock on the log while the row is written. Give up after 5 s rather than
# hang the event: PreModelSwitch blocks the switch when its hook times out.
exec 9>>"$log"
flock -w 5 9
jq -c --arg ts "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)" --arg event "$event" --arg action "${1:-}" \
  '{ts: $ts, event: $event}
   + (if $action == "" then {} else {action: $action} end)
   + {input: .}' <<<"$input" >&9
