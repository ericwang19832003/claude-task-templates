# claude-task-templates

A repo-local memory layer for long-running Claude Code sessions and multi-session
orchestration. One folder per task in `.claude-task/<slug>/`, six fixed files,
YAML frontmatter as the orchestrator contract.

**Goals:**

1. A session can be reset (or `/clear`-ed) at any time without losing important state.
2. Context doesn't grow unboundedly and degrade model performance.
3. A brand-new agent can take over a task within **5 minutes** by reading the memory files.
4. An orchestrator (script, scheduled trigger, dashboard) can read task status programmatically.
5. Repeated work and back-and-forth across sessions is reduced.

**Spec:** [`docs/specs/2026-04-20-design.md`](docs/specs/2026-04-20-design.md)
**Implementation plan:** [`docs/specs/2026-04-20-plan.md`](docs/specs/2026-04-20-plan.md)

## Install

```bash
git clone https://github.com/<you>/claude-task-templates.git ~/claude-task-templates
echo 'export PATH="$HOME/claude-task-templates/bin:$PATH"' >> ~/.bashrc
exec $SHELL
```

(On Windows under Git Bash, use the same lines — `~/.bashrc` is the Git Bash startup file.)

## Use

In any repo where you want cross-session task memory:

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

Then:

1. Fill `BRIEF.md` (~5 min, write-once).
2. Edit `NEXT.md` with the first concrete action.
3. Set `status: in_progress` in `STATUS.md` when you start.
4. **Checkpoint** at every natural pause: rewrite `STATUS.md` and `NEXT.md`, append to `LOG.md`. ~2 min.
5. **Takeover** in any new session: `cat .claude-task/ACTIVE`, then read `STATUS.md` → `BRIEF.md` → `NEXT.md`. ~5 min.

Add this snippet to your repo's `CLAUDE.md` so every Claude Code session sees it at startup:

```bash
cat ~/claude-task-templates/snippets/CLAUDE.md.snippet >> CLAUDE.md
```

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
