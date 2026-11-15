# Event log

One row in `.skogai/logs/skogai-core/log.jsonl` at the git root for each event we act upon, and what we did:

```json
{"ts":"2026-10-14T12:56:01.123Z","event":"Stop","action":"journal entry, git add -A","input":{...the hook's stdin JSON...}}
```

| Field | What it holds |
|---|---|
| `ts` | When the row was written, UTC, millisecond precision |
| `event` | The hook event name (`hook_event_name`), such as `Stop` |
| `action` | What the script did, passed as `append-json.sh`'s argument. Left out when the script only logged |
| `input` | The hook's stdin JSON, unchanged |

Other features read these `input` fields, so they must stay in the log:

- `prompt_id`: groups a turn's rows. `Stop.sh` finds the turn's prompt and tool uses with it.
- `agent_id`: set on rows from inside a subagent, which share the parent's `prompt_id`. `Stop.sh` skips them.
- `prompt` (`UserPromptSubmit`), `tool_name` and `tool_input` (`PostToolUse`, `PostToolUseFailure`): the journal entry's prompt and actions.
- `last_assistant_message` and `cwd` (`Stop`): the reply, and where to find the git root.

## Why

skogai-core exists to act upon events. The log is the record of every time it did, and the source the other features read from: the status line shows its last row, and the journal finds a turn's prompt and tool uses in it.

## How

- `hooks/hooks.json` is the list of events we act upon. Each one runs `scripts/events/<Event>.sh` with the event's JSON on stdin.
- Each script does what that event needs, then calls `scripts/append-json.sh [action]`, which appends one row with `>>` under `flock`.
- To act upon another event: [README.md#acting-upon-another-event](../../README.md#acting-upon-another-event).

## Status

- Built in 0.5.0: `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `Notification`, `SubagentStart`, `SubagentStop`, `PreCompact`, `PostCompact`, `Stop`, `StopFailure`, `SessionEnd`. Every one except `StopFailure` has been seen live.
- Added in 0.11.0, log only: `Setup`, `InstructionsLoaded`, `UserPromptExpansion`, `MessageDisplay`, `PermissionRequest`, `PermissionDenied`, `PostToolBatch`, `TaskCreated`, `TaskCompleted`, `TeammateIdle`, `ConfigChange`, `CwdChanged`, `DirectoryAdded`, `FileChanged`, `PreModelSwitch`, `PostModelSwitch`, `Elicitation`, `ElicitationResult`. That is 31 of the 33 events in the hooks reference.
- `MessageDisplay` runs with `async: true`: Claude Code holds each batch of streamed text until a synchronous hook returns, and a log row is not worth that wait. Its rows can land out of `index` order, and under `claude -p` the last one can be lost when the session is torn down.
- `FileChanged` only fires for filenames listed in its matcher, which are literal names in the working directory, not patterns. `hooks.json` lists `.envrc`, `.env`, `mise.toml`, `.mise.toml` and `.mcp.json`. They are looked up in the session's working directory, so a session started in a subdirectory misses the ones at the git root.
- `tests/run.sh` checks the row format without a session, that `hooks.json` and `scripts/events/` list the same events, and that every script writes its row.

## Left out on purpose

- Never committed; `log.jsonl` is gitignored.
- `WorktreeCreate` and `WorktreeRemove`. A `WorktreeCreate` hook replaces Claude Code's own `git worktree` step and must create the worktree and print its path, so one that only logs would break `claude --worktree` and worktree-isolated subagents. `WorktreeRemove` only fires for worktrees such a hook created.
- Mod-only events (`prompt.compose`, `ui.*`, `turn.complete`, ...). We act upon plain hook events only.
