# Next: questions, proposals, ideas

Written 2026-11-15, at the end of the session that split this plugin out of skogai2/marketplace. Read it, answer what needs answering, and delete it once its items are done or moved to issues.

Each item says whether I checked it (**seen**) or am inferring it (**not checked**).

## Where things stand

- skogai-events 0.12.0, this repo, public, CI green. Installed at user scope on this machine, all 14 settings unset, so it logs nothing.
- 31 of the 33 documented hook events have a script. 8 have been seen firing live: `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `PostToolBatch`, `MessageDisplay`, `Stop`, `SessionEnd`. The rest are covered only by `tests/run.sh` feeding each script a sample row.
- `plugins/skogai-core` in the marketplace is frozen at 0.11.1 and still installed here, disabled.

## Questions for you

One decision each. My pick is first.

1. **License.** `claude plugin validate .` says the plugin directory refuses a plugin with no `LICENSE` file and no `license` in `plugin.json` (seen). skogai-council is MIT (seen). MIT here too?
2. **What happens to skogai-core.** Options: leave it frozen with no end date; add a line to its README pointing here; or later add `"renames": {"skogai-core": "skogai-events"}` to the marketplace header and delete it, which is what workorder 0001 step B1 planned. Which, and when?
3. **Your old skogai-core options.** They turn on stage, commit and merge on every prompt and every stop, and put the log, journal and state under `.skogai/logs/` (seen in `~/.claude/settings.json`). I did not copy them to skogai-events. Copy them as they are, or start from a smaller set?
4. **`FileChanged` watch list.** It only fires for literal filenames. I chose `.envrc`, `.env`, `mise.toml`, `.mise.toml`, `.mcp.json`. Is that the right list, and should it be a setting instead of a constant in `scripts/generate-hooks-json.sh`?
5. **The two worktree events.** They are left out because a `WorktreeCreate` hook replaces Claude Code's own `git worktree` step. To log them, the hook has to create the worktree itself. Do you want that, done with `wt`, or are 31 events enough?
6. **Org.** This repo is in `skogai`; the marketplace and dash are in `skogai2`. Intended, or should one side move?
7. **Workorder 0001.** It lives in the marketplace and still says the rename happens inside `plugins/`. Move it here and rewrite section B for this repo? Its open question 1 (where a dot records its dash ref) still blocks B2.
8. **T3 Code.** I read "use t3code for feedback" as: start a review thread with `t3 thread start` and read its reply. Is that what you meant? The marketplace project has no default model, so every start needs `--provider claudeAgent --model claude-opus-5-5`; do you want a default set?
9. **`MessageDisplay` in the default.** `events` defaults to `*`, which includes a row per batch of streamed text. Keep it in the default, or make the default everything except `MessageDisplay`?

## Proposals

Things I would do next, in the order I would do them.

1. **Trigger the 16 events not yet seen live.** A checklist, one line per event with how to make it fire (`/model` for the model-switch pair, an MCP elicitation, `/add-dir`, a `cd` for `CwdChanged`, a task list for the task pair, an agent team for `TeammateIdle`, `claude --init-only` for `Setup`, and so on), ticking each off when its row shows up. Until then "31 events" is partly a claim about the docs.
2. **Make every log-only hook async, not only `MessageDisplay`.** A synchronous hook costs about 150 ms per event on this machine, because `jq` is a mise shim at about 70 ms per call and each row takes two calls (seen, timed). A tool call fires three hooks (`PreToolUse`, `PostToolUse`, `PostToolBatch`), so that is close to half a second per tool call of pure logging. The cost: rows can land out of order, and the status line reads the last row right after the event, so it could lag by one. The three scripts that act (`SessionStart`, `UserPromptSubmit`, `Stop`) stay synchronous.
3. **Or take the shim out of the hot path.** Resolve the real `jq` once (`mise which jq` takes 2 ms per call instead of 70, seen) and cache the path, or drop to one `jq` call per row. Smaller change than 2, and it keeps ordering. 2 and 3 can both be done.
4. **Fix the `tool.call` warning in `hooks/register.ts`.** The validator reports "gating hook without .catch: tool.call" (seen). LEARNINGS.md says one throwing hook stops the whole module loading, so this is worth closing.
5. **Decide what the log may contain.** Rows hold the hook's full input: prompts, tool inputs, tool responses. A `Read` of a secrets file would put its contents in `event.jsonl` (not checked, inferred from the row format). Nothing redacts or caps it, and nothing rotates the file. Your rule is working first, hardening after, so this is a later step, but it should be a known one.
6. **Pin what users get.** The marketplace entry points at this repo with no ref, so every push to `master` here is what the next install or update gets (not checked how often clients refresh). Tag releases and pin the marketplace entry to a tag, so working here "100%" cannot break an installed copy.
7. **Per-event switches** (workorder decision 6, step B6): each event off unless switched on, replacing the `events` glob. With 31 events this matters more than it did with 13.
8. **Event schemas in dash.** The workorder's A3 wrote 13 event instances and schemas. There are now 31 scripts, so 18 have no instance, and the workorder's "done when: 13 instances" is out of date.
9. **A review thread before each push.** The one this session found two real bugs, one of which my own change had made worse. Cheap enough to make routine for anything touching the scripts.

## Smaller ideas

- **Tests.** `tests/run.sh` has no per-test selection. `bats` is already pinned in the marketplace's `mise.toml`; moving to it would give that. The marketplace `TODO.md` also asks for a `*.test.ts` so `claude plugin test` has something to run for the status line.
- **CI.** Add `shellcheck`. `claude plugin validate` cannot run there without Claude Code installed.
- **`wt` is a dependency that is not declared.** `write-state.sh` and `git-steps.sh` call it; this repo's `mise.toml` pins only `jq`. Add worktrunk, or note that the marketplace's "`mise install` fails for worktrunk" still applies (not checked whether it still fails).
- **A lock timeout is now an error.** `append-json.sh` gives up on the log lock after 5 s and exits 1, which shows a hook error notice. That is on purpose (a failure you can see beats a hung model switch), but if it ever shows up it means something held the log for 5 s.
- **Docs that overlap.** `README.md`, `FEATURES.md`, `DIFF-AS-CONTEXT.md` and `.skogai/features/*.md` describe the same three features at different lengths. `CONFIG.md` describes a design that is "not wired in" and belongs with dash more than here. Feature docs sit in a hidden `.skogai/features/`; your rule elsewhere is `doc/`.
- **A viewer.** `tail -f .skogai/logs/event.jsonl | jq -c '{event, action}'` is the only way to watch the log. A small `argc` command (tail, filter by event, show one turn by `prompt_id`) would make it usable by a person, in line with workorder decision 4.

## Loose ends I noticed and did not touch

- Marketplace `.gitignore` lines 7 and 8 are the same line (seen).
- Marketplace `APM.md` line 30 says skogai-core's hooks are broken under apm because `events/*.sh` are copied without the `settings.sh` they source (seen in the file, not re-tested). The same would now apply to `guard.sh`, and to this repo.
- The marketplace journal mentions a line `**/.skogai/logs/skogai-core/` in `~/.config/git/ignore` (not checked). The new log path is `.skogai/logs/event.jsonl`, which that line does not cover; this repo's own `.gitignore` covers `.skogai/logs/` only for this repo.
- The description in the marketplace entry for skogai-events is identical to skogai-core's (seen), so the two are hard to tell apart in a plugin list.

## What I did without being asked

So you can undo any of it.

- `scripts/generate-hooks-json.sh` and its `--check`; `hooks/hooks.json` is now generated.
- `.github/workflows/test.yml`, `mise.toml` (jq only), `CLAUDE.md`.
- The log path changed to `.skogai/logs/event.jsonl` and the journal commit message to `skogai-events: journal`, following the workorder.
- A paragraph in the marketplace `CLAUDE.md` saying skogai-core is frozen.
