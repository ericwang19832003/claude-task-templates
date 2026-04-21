#!/usr/bin/env bash
# claude-memory one-line installer.
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/ericwang19832003/claude-memory/main/install.sh | bash
#
# Idempotent: safe to re-run. Updates the local repo, adds PATH on first run,
# merges global CLAUDE.md and ~/.claude/settings.json hooks without clobbering
# existing content.

set -euo pipefail

REPO_URL="${CTT_REPO_URL:-https://github.com/ericwang19832003/claude-memory.git}"
INSTALL_DIR="${CTT_INSTALL_DIR:-$HOME/claude-memory}"
CLAUDE_DIR="$HOME/.claude"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
GLOBAL_CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
MARKER="<!-- claude-memory: managed block — do not edit between markers -->"
END_MARKER="<!-- /claude-memory -->"

step() { printf "\033[1;36m▸\033[0m %s\n" "$1"; }
ok()   { printf "\033[1;32m✓\033[0m %s\n" "$1"; }
warn() { printf "\033[1;33m!\033[0m %s\n" "$1"; }

# 1. Verify prerequisites
step "Checking prerequisites"
for cmd in git; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: '$cmd' is required but not found in PATH." >&2
    exit 1
  fi
done
PYTHON=$(command -v python3 || command -v python || echo "")
if [ -z "$PYTHON" ]; then
  echo "Error: python3 (or python) is required but not found in PATH." >&2
  exit 1
fi
ok "git and python present ($PYTHON)"

# 2. Clone or update the repo
if [ -d "$INSTALL_DIR/.git" ]; then
  step "Updating existing install at $INSTALL_DIR"
  git -C "$INSTALL_DIR" pull --ff-only --quiet || warn "Pull skipped (uncommitted local changes)"
else
  step "Cloning to $INSTALL_DIR"
  git clone --quiet "$REPO_URL" "$INSTALL_DIR"
fi
chmod +x "$INSTALL_DIR/bin/"* 2>/dev/null || true
ok "Repo ready at $INSTALL_DIR"

# 3. Add bin/ to PATH in shell rc files (idempotent)
step "Wiring PATH"
PATH_LINE='export PATH="$HOME/claude-memory/bin:$PATH"  # claude-memory'
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  if [ -f "$rc" ]; then
    if ! grep -qF 'claude-memory' "$rc"; then
      printf '\n# claude-memory\n%s\n' "$PATH_LINE" >> "$rc"
      ok "Appended to $rc"
    else
      ok "$rc already references claude-memory"
    fi
  fi
done
# Ensure at least one rc file exists with the line
if [ ! -f "$HOME/.bashrc" ] && [ ! -f "$HOME/.zshrc" ]; then
  printf '%s\n' "$PATH_LINE" > "$HOME/.bashrc"
  ok "Created ~/.bashrc with PATH line"
fi

# 4. Install / append global CLAUDE.md behavior contract
step "Installing global ~/.claude/CLAUDE.md"
mkdir -p "$CLAUDE_DIR"
SNIPPET="$INSTALL_DIR/snippets/CLAUDE.md.user-snippet"
if [ -f "$GLOBAL_CLAUDE_MD" ] && grep -qF "$MARKER" "$GLOBAL_CLAUDE_MD"; then
  ok "Global CLAUDE.md already has managed block"
else
  {
    [ -f "$GLOBAL_CLAUDE_MD" ] && cat "$GLOBAL_CLAUDE_MD"
    [ -f "$GLOBAL_CLAUDE_MD" ] && printf '\n'
    printf '%s\n' "$MARKER"
    cat "$SNIPPET"
    printf '%s\n' "$END_MARKER"
  } > "$GLOBAL_CLAUDE_MD.tmp"
  mv "$GLOBAL_CLAUDE_MD.tmp" "$GLOBAL_CLAUDE_MD"
  ok "Wrote $GLOBAL_CLAUDE_MD"
fi

# 5. Merge hooks into ~/.claude/settings.json (using Python for safe JSON merge)
step "Merging hooks into ~/.claude/settings.json"
$PYTHON - "$SETTINGS_FILE" <<'PY'
import json, os, sys, pathlib

p = pathlib.Path(sys.argv[1])
home = os.path.expanduser("~").replace("\\", "/")
# Use absolute paths so the hook resolves regardless of cwd / shell.
checkpoint = f"{home}/claude-memory/bin/claude-task-checkpoint --source hook"
context    = f"{home}/claude-memory/bin/claude-task-context"

CHECKPOINT_HOOK = {
    "hooks": [
        {"type": "command", "command": checkpoint, "shell": "bash", "timeout": 10}
    ]
}
CONTEXT_HOOK = {
    "hooks": [
        {"type": "command", "command": context, "shell": "bash", "timeout": 5}
    ]
}

settings = {}
if p.exists():
    try:
        settings = json.loads(p.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        print(f"  ! existing settings.json is not valid JSON: {e}", file=sys.stderr)
        print( "    leaving it alone — please fix manually before re-running.", file=sys.stderr)
        sys.exit(2)

settings.setdefault("hooks", {})

def already_present(event_list, command_substring):
    for entry in event_list:
        for h in entry.get("hooks", []):
            if h.get("type") == "command" and command_substring in h.get("command", ""):
                return True
    return False

settings["hooks"].setdefault("SessionEnd", [])
if not already_present(settings["hooks"]["SessionEnd"], "claude-task-checkpoint"):
    settings["hooks"]["SessionEnd"].append(CHECKPOINT_HOOK)
    print("  added SessionEnd -> claude-task-checkpoint")
else:
    print("  SessionEnd -> claude-task-checkpoint already present")

settings["hooks"].setdefault("UserPromptSubmit", [])
if not already_present(settings["hooks"]["UserPromptSubmit"], "claude-task-context"):
    settings["hooks"]["UserPromptSubmit"].append(CONTEXT_HOOK)
    print("  added UserPromptSubmit -> claude-task-context")
else:
    print("  UserPromptSubmit -> claude-task-context already present")

p.parent.mkdir(parents=True, exist_ok=True)
p.write_text(json.dumps(settings, indent=2) + "\n", encoding="utf-8")
print(f"  wrote {p}")
PY

ok "Hooks merged"

# 6. Bootstrap global task memory
step "Bootstrapping global task memory"
# Note: checks directory existence only; a partial init from a prior failed run
# would require manual cleanup with: rm -rf ~/.claude-task/general
export PATH="$INSTALL_DIR/bin:$PATH"
if [ ! -d "$HOME/.claude-task/general" ]; then
  if "$INSTALL_DIR/bin/claude-task-init" general --title "Global session memory" --global; then
    ok "Global task memory ready at ~/.claude-task/general/"
  else
    warn "Could not create global task memory — run manually: claude-task-init general --title 'Global session memory' --global"
  fi
else
  ok "Global task memory already exists at ~/.claude-task/general/"
fi

# 7. Summary
echo
printf "\033[1;32m✓ Installation complete.\033[0m\n"
echo
echo "Next steps:"
echo "  1. Open a new shell (or run 'exec \$SHELL') so the new PATH takes effect."
echo "  2. Inside Claude Code, type /hooks once and dismiss it — that reloads the"
echo "     settings watcher and activates both hooks for the current session."
echo "  3. Global memory is active. Claude Code will remember context across sessions"
echo "     automatically. Run 'claude-task-init <slug> --title \"...\"' inside a repo"
echo "     to create project-specific task memory."
echo
echo "Verify the install:"
echo "  mkdir /tmp/cttest && cd /tmp/cttest"
echo "  claude-task-init demo --title 'Demo'"
echo "  echo '{}' | claude-task-context | python3 -m json.tool"
echo
echo "Read more: https://github.com/ericwang19832003/claude-memory"
