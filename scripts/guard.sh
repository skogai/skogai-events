#!/usr/bin/env bash
# Sourced first by every hook script, before it reads stdin or starts jq or git.
# With the `enabled` mod setting off (the default) the hook ends here, so an
# idle plugin costs one bash start per event and nothing else.
[[ ${CLAUDE_PLUGIN_OPTION_ENABLED:-false} == true ]] || exit 0

# Exit code 2 from a hook blocks the event (tool call, model switch, prompt
# expansion, ...), and jq exits 2 on a system error such as a full disk. A
# failed log write must never block anything, so report it as a plain error.
trap 'status=$?; [[ $status -ne 2 ]] || exit 1' EXIT
