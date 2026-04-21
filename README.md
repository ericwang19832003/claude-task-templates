# claude-memory

Cross-session memory for Claude Code. Install once — Claude remembers context across every session, automatically.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/ericwang19832003/claude-memory/main/install.sh | bash
```

Then open a new shell, and inside Claude Code type `/hooks` once and dismiss it.

**That's it. Memory is on.**

---

## What happens automatically

After install, every Claude Code session on your machine:

- **Picks up where you left off** — Claude reads the active task context on every prompt, no re-explaining needed
- **Saves progress** — at the end of each session, a checkpoint is written automatically
- **Self-heals** — if memory files are ever deleted, they're recreated silently on the next prompt

---

## Project-specific memory (automatic)

When you start a substantial piece of work inside a repo, Claude automatically creates a dedicated memory folder for it — no commands needed. Just describe what you're building and Claude scaffolds it.

The folder looks like this:

```
your-repo/
  .claude-task/
    my-task/
      STATUS.md     — current state (kept up to date by Claude)
      BRIEF.md      — goal, scope, success criteria
      NEXT.md       — next 1–3 concrete steps
      DECISIONS.md  — irreversible choices + rationale
      LOG.md        — session journal
      ARTIFACTS.md  — commits, PRs, files produced
```

Project memory takes priority over global memory when you're inside that repo, so Claude always knows the full context of the work in progress.

---

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/ericwang19832003/claude-memory/main/uninstall.sh | bash
```

---

## For teams

If collaborators don't have the system installed, add this to your repo's `CLAUDE.md` so they still get basic context when they clone:

```bash
cat ~/claude-memory/snippets/CLAUDE.md.snippet >> CLAUDE.md
```

---

## How it fits with Claude Code's built-in memory

| Layer | Lives in | Lifetime | Purpose |
|---|---|---|---|
| **Auto-memory** (built-in) | `~/.claude/projects/.../memory/` | Months–years | User profile, preferences, project background |
| **Task memory** (this) | `~/.claude-task/` or `<repo>/.claude-task/` | Hours–weeks | Cross-session handoff: decisions, log, artifacts |
| **Session tasks** (built-in) | `~/.claude/tasks/` | One session | Within-session step tracking |

---

## License

MIT
