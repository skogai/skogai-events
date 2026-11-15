#!/usr/bin/env bash
# Writes hooks/hooks.json from the scripts in scripts/events/: one command hook
# per <Event>.sh, plus the status-line module. Never hand-edit hooks.json.
# Usage: generate-hooks-json.sh [--check]   (--check fails if the file drifted)
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
out=$root/hooks/hooks.json

# The two events that need more than a command:
#   MessageDisplay  async, because Claude Code holds streamed text until a
#                   synchronous hook returns
#   FileChanged     only fires for the literal filenames in its matcher
# Sorted in the C locale, so the file is the same on every machine.
generated=$(cd "$root/scripts/events" && ls -- *.sh | sed 's/\.sh$//' | LC_ALL=C sort | jq -Rn '
  {modules: ["./register.ts"], hooks: ([inputs] | map({key: ., value: [
    (if . == "FileChanged" then {matcher: ".envrc|.env|mise.toml|.mise.toml|.mcp.json"} else {} end)
    + {hooks: [{type: "command", command: "\"${CLAUDE_PLUGIN_ROOT}/scripts/events/\(.).sh\""}
       + (if . == "MessageDisplay" then {async: true} else {} end)]}]}) | from_entries)}')

if [[ ${1:-} == --check ]]; then
  diff <(echo "$generated") "$out" >&2 || { echo "hooks/hooks.json drifted: run scripts/generate-hooks-json.sh" >&2; exit 1; }
  echo "hooks/hooks.json is up to date"
else
  echo "$generated" >"$out"
  echo "wrote $out"
fi
