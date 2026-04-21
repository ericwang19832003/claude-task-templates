# Zero-Setup Global Memory Design

**Date:** 2026-04-21
**Status:** Approved

## Problem

`claude-task-init general --title "My ongoing work" --global` is too long for users to remember. Global cross-session memory should require zero commands after install.

## Goal

Memory is active the moment `install.sh` finishes. No extra commands. Self-healing if ever deleted.

## Approach: Belt + Suspenders (Option 3)

Two changes, two files.

### 1. `install.sh` — auto-init at end of install

Add a new step after hooks are merged:

- Call `claude-task-init general --title "Global session memory" --global`
- Idempotent: skip if `~/.claude-task/general/` already exists
- Inform user: "Global task memory ready at ~/.claude-task/general/"

### 2. `bin/claude-task-context` — self-heal if global task missing

After the global fallback check (when no repo-local `.claude-task/` is found):

- If `~/.claude-task/ACTIVE` does not exist, auto-run `claude-task-init --global`
- Use absolute path `~/claude-task-templates/bin/claude-task-init` (hook may not have PATH)
- Suppress all output — hook must stay silent
- Never fail (`|| true`) — hook failure breaks every prompt

### Priority order (unchanged)

1. Repo-local `.claude-task/` — if anywhere in the directory tree
2. Global `~/.claude-task/` — everywhere else (auto-created if missing)

## What Users Experience

1. Run `curl ... | bash` — install finishes, global memory is live
2. Open Claude Code anywhere — context injected automatically
3. If `~/.claude-task/` deleted — hook recreates it silently on next prompt

## Files Changed

- `install.sh` — new step 6: scaffold global task
- `bin/claude-task-context` — auto-heal if global task missing
