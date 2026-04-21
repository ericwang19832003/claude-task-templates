# claude-task-templates

Cross-session memory for Claude Code — automatic from the moment you install.
No commands needed. Claude remembers context across sessions everywhere on your machine.

For long-running or repo-specific work, one folder per task in `.claude-task/<slug>/`,
six fixed files, YAML frontmatter as the orchestrator contract.

**Goals:**

1. Memory is active the moment you install — zero extra commands required.
2. A session can be reset (or `/clear`-ed) at any time without losing important state.
3. Context doesn't grow unboundedly and degrade model performance.
4. A brand-new agent can take over a task within **5 minutes** by reading the memory files.
5. An orchestrator (script, scheduled trigger, dashboard) can read task status programmatically.
6. Repeated work and back-and-forth across sessions is reduced.

**Spec:** [`docs/specs/2026-04-20-design.md`](docs/specs/2026-04-20-design.md)
**Implementation plan:** [`docs/specs/2026-04-20-plan.md`](docs/specs/2026-04-20-plan.md)

## Install

**One-line install (recommended).** Works on macOS, Linux, and Windows (Git Bash):

```bash
curl -fsSL https://raw.githubusercontent.com/ericwang19832003/claude-task-templates/main/install.sh | bash
```

This installer:

1. Clones the repo to `~/claude-task-templates` (or pulls if it already exists).
2. Adds `bin/` to your `PATH` via `~/.bashrc` and `~/.zshrc` (if either exists).
3. Appends a global behavior contract to `~/.claude/CLAUDE.md` (so every Claude session knows the protocol).
4. Merges two hooks into `~/.claude/settings.json`:
   - `SessionEnd` → auto-checkpoint on session end
   - `UserPromptSubmit` → inject active-task context on every prompt
5. **Creates global task memory at `~/.claude-task/general/`** — active immediately, everywhere.
6. Refuses to clobber. Re-run any time to update.

After install, open a new shell, then inside Claude Code type `/hooks` once and dismiss it. **That's it — memory is on.**

**Manual install (if you prefer to see what's happening):**

```bash
git clone https://github.com/ericwang19832003/claude-task-templates.git ~/claude-task-templates
echo 'export PATH="$HOME/claude-task-templates/bin:$PATH"' >> ~/.bashrc
cp ~/claude-task-templates/snippets/CLAUDE.md.user-snippet ~/.claude/CLAUDE.md
# Then merge the SessionEnd + UserPromptSubmit hooks into ~/.claude/settings.json
# (see the "Auto-checkpoint" and "Auto-context injection" sections below)
exec $SHELL
```

(Windows users: the same lines work in Git Bash.)

## Use

### Zero-setup (automatic)

After install, **nothing to do.** Open Claude Code anywhere on your machine and memory is already active. Claude automatically picks up context from the previous session on every prompt.

The global memory lives at `~/.claude-task/general/` and is self-healing — if it ever gets deleted, the hook recreates it silently on the next prompt.

### Project-specific task memory (optional)

For work that spans many sessions and deserves its own dedicated log, decisions, and artifacts:

```bash
cd path/to/your-repo
claude-task-init my-task --title "Implement payment retry logic"
```

That creates:

```
your-repo/
  .claude-task/
    README.md            (committed; explains the protocol to anyone who clones)
    ACTIVE               (one line: "my-task")
    my-task/
      STATUS.md          (current state + machine-readable YAML frontmatter)
      BRIEF.md           (goal, scope, success criteria — fill this in once)
      NEXT.md            (concrete next 1–3 steps)
      DECISIONS.md       (irreversible choices + why-lines)
      LOG.md             (append-only journal)
      ARTIFACTS.md       (pointers to commits, PRs, files, URLs)
  .gitignore             (auto-appended; .claude-task/* with !.claude-task/README.md)
```

Project-specific tasks take priority over the global memory. When you're inside a repo that has `.claude-task/`, that context is injected instead.

Then:

1. Fill `BRIEF.md` (~5 min, write-once).
2. Edit `NEXT.md` with the first concrete action.
3. Set `status: in_progress` in `STATUS.md` when you start.
4. **Checkpoint** at every natural pause: rewrite `STATUS.md` and `NEXT.md`, append to `LOG.md`. ~2 min.
5. **Takeover** in any new session: `cat .claude-task/ACTIVE`, then read `STATUS.md` → `BRIEF.md` → `NEXT.md`. ~5 min.

**For collaborators who don't have the system installed:** add this minimal snippet to your repo's `CLAUDE.md` so they still get basic takeover instructions when they clone:

```bash
cat ~/claude-task-templates/snippets/CLAUDE.md.snippet >> CLAUDE.md
```

If everyone on your team has run the installer, you don't need this — the global `~/.claude/CLAUDE.md` already covers it.

## Auto-checkpoint via SessionEnd hook (optional but recommended)

The system relies on the agent (or you) calling `claude-task-checkpoint` at natural pauses. To guarantee at least one checkpoint per session, wire the included script into a Claude Code SessionEnd hook so it fires automatically when a session ends:

Add to `~/.claude/settings.json` (merging with any existing settings):

```json
{
  "hooks": {
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/claude-task-templates/bin/claude-task-checkpoint --source hook",
            "shell": "bash",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

The script is idempotent and silently no-ops in repos without a `.claude-task/` folder, so it's safe to fire on every session in every repo. When it does fire on a task repo, it bumps `STATUS.md` `updated`, appends a one-line auto-checkpoint entry to `LOG.md`, and warns to stderr if `NEXT.md` still has placeholder text.

Run manually any time:

```bash
claude-task-checkpoint --reason "wrapping up phase 0"
```

## Auto-context injection via UserPromptSubmit hook (recommended)

For *fully* hands-free operation: a second hook (`UserPromptSubmit`) runs `claude-task-context` on every prompt. The script reads the active task's STATUS frontmatter, "Where we are" paragraph, and NEXT.md "Now" section, and injects them as `additionalContext` for the model. Claude then *automatically knows* which task you're on, what was decided, and what to do next — without you typing a word.

Add to `~/.claude/settings.json` (merging with the SessionEnd hook above):

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/claude-task-templates/bin/claude-task-context",
            "shell": "bash",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

Cost: ~250–400 tokens injected per prompt, capped at ~1.5 KB. Silent no-op when no `.claude-task/` is in scope, so safe to enable globally.

Pair with a global `~/.claude/CLAUDE.md` that tells Claude how to *act* on the injected context — see `snippets/CLAUDE.md.user-snippet` in this repo for a ready-to-use behavior contract covering: takeover on first prompt, checkpoint at natural pauses, scaffold-on-substantial-work, archive on done.

## Orchestrator API

The YAML frontmatter in `<slug>/STATUS.md` is the contract. Read it from any language:

**Python (no dependencies):**

```python
import yaml, pathlib, re
for f in pathlib.Path('.claude-task').glob('*/STATUS.md'):
    text = f.read_text()
    m = re.match(r'---\n(.*?)\n---', text, re.S)
    if m:
        fm = yaml.safe_load(m.group(1))
        print(fm['task_id'], fm['status'], fm['updated'])
```

**bash + yq:**

```bash
for d in .claude-task/*/; do
  [ -f "$d/STATUS.md" ] || continue
  yq -f extract '. | "\(.task_id)\t\(.status)\t\(.owner)\t\(.updated)"' "$d/STATUS.md"
done
```

## How this fits with existing Claude Code memory

Three coexisting layers, each with a different timescale:

| Layer | Where | Lifetime | Purpose |
|---|---|---|---|
| **Auto-memory** (Claude built-in) | `~/.claude/projects/.../memory/` | Months/years | User profile, feedback rules, project background |
| **Task memory** (this) | `<repo>/.claude-task/<slug>/` | Hours-to-weeks | Cross-session handoff: decisions, log, artifacts |
| **Harness tasks** (Claude built-in) | `~/.claude/tasks/<session>/<id>.json` | One session | Within-session step tracking via `TaskCreate`/`TaskUpdate` |

This repo only addresses the middle layer. The other two stay as-is.

## License

MIT
