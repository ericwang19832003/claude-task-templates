#!/usr/bin/env bash
# claude-memory uninstaller.
# Reverses everything install.sh did — safe to run even if install was partial.
# Does NOT delete .claude-task/ folders inside your repos.

set -euo pipefail

INSTALL_DIR="${CTT_INSTALL_DIR:-$HOME/claude-memory}"
CLAUDE_DIR="$HOME/.claude"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
GLOBAL_CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
MARKER="<!-- claude-memory: managed block — do not edit between markers -->"
END_MARKER="<!-- /claude-memory -->"

step() { printf "\033[1;36m▸\033[0m %s\n" "$1"; }
ok()   { printf "\033[1;32m✓\033[0m %s\n" "$1"; }
warn() { printf "\033[1;33m!\033[0m %s\n" "$1"; }

PYTHON=$(command -v python3 || command -v python || echo "")

# 1. Remove managed block from ~/.claude/CLAUDE.md
step "Removing managed block from ~/.claude/CLAUDE.md"
if [ -f "$GLOBAL_CLAUDE_MD" ] && grep -qF "$MARKER" "$GLOBAL_CLAUDE_MD"; then
  # Use Python/awk to strip the block between markers (inclusive)
  if [ -n "$PYTHON" ]; then
    $PYTHON - "$GLOBAL_CLAUDE_MD" <<'PY'
import sys, pathlib

p = pathlib.Path(sys.argv[1])
text = p.read_text(encoding="utf-8")
START = "<!-- claude-memory: managed block — do not edit between markers -->"
END   = "<!-- /claude-memory -->"
start_idx = text.find(START)
end_idx   = text.find(END, start_idx)
if start_idx == -1 or end_idx == -1:
    print("  block not found — nothing to remove")
    sys.exit(0)
# Strip a leading blank line before the marker if present
before = text[:start_idx].rstrip('\n')
after  = text[end_idx + len(END):].lstrip('\n')
result = before + ('\n' if before else '') + after
p.write_text(result, encoding="utf-8")
print(f"  removed managed block from {p}")
PY
  else
    warn "python not found — skipping CLAUDE.md cleanup (remove manually between markers)"
  fi
else
  ok "No managed block found in CLAUDE.md — nothing to do"
fi

# 2. Remove hooks from ~/.claude/settings.json
step "Removing hooks from ~/.claude/settings.json"
if [ -f "$SETTINGS_FILE" ] && [ -n "$PYTHON" ]; then
  $PYTHON - "$SETTINGS_FILE" <<'PY'
import json, sys, pathlib

p = pathlib.Path(sys.argv[1])
if not p.exists():
    print("  settings.json not found — nothing to do")
    sys.exit(0)

try:
    settings = json.loads(p.read_text(encoding="utf-8"))
except json.JSONDecodeError as e:
    print(f"  ! settings.json is not valid JSON: {e}", file=sys.stderr)
    sys.exit(2)

hooks = settings.get("hooks", {})
changed = False

def remove_ctt_hooks(event_list):
    global changed
    result = []
    for entry in event_list:
        filtered = [
            h for h in entry.get("hooks", [])
            if "claude-task-" not in h.get("command", "")
        ]
        if len(filtered) != len(entry.get("hooks", [])):
            changed = True
        if filtered:
            result.append({**entry, "hooks": filtered})
        else:
            changed = True  # dropped empty entry
    return result

for event in ["SessionEnd", "UserPromptSubmit"]:
    if event in hooks:
        hooks[event] = remove_ctt_hooks(hooks[event])
        if not hooks[event]:
            del hooks[event]

if changed:
    p.write_text(json.dumps(settings, indent=2) + "\n", encoding="utf-8")
    print(f"  removed claude-task hooks from {p}")
else:
    print("  no claude-task hooks found — nothing to do")
PY
elif [ ! -f "$SETTINGS_FILE" ]; then
  ok "settings.json not found — nothing to do"
else
  warn "python not found — skipping settings.json cleanup (remove hooks manually)"
fi

# 3. Remove PATH line from shell rc files
step "Removing PATH line from shell rc files"
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  if [ -f "$rc" ] && grep -qF 'claude-memory' "$rc"; then
    # Remove the comment + export line (both lines)
    grep -v 'claude-memory' "$rc" > "$rc.ctt-tmp" && mv "$rc.ctt-tmp" "$rc"
    ok "Removed from $rc"
  else
    [ -f "$rc" ] && ok "$rc — no entry found"
  fi
done

# 4. Optionally remove the install directory
step "Removing install directory"
if [ -d "$INSTALL_DIR" ]; then
  printf "Remove %s? [y/N] " "$INSTALL_DIR"
  read -r answer </dev/tty
  case "$answer" in
    [Yy]*) rm -rf "$INSTALL_DIR"; ok "Removed $INSTALL_DIR";;
    *) warn "Skipped — $INSTALL_DIR left in place";;
  esac
else
  ok "$INSTALL_DIR not found — nothing to remove"
fi

echo
printf "\033[1;32m✓ Uninstall complete.\033[0m\n"
echo
echo "Note: .claude-task/ folders inside your repos were NOT touched."
echo "Delete them manually if you no longer want task memory in those repos."
echo "Open a new shell for PATH changes to take effect."
