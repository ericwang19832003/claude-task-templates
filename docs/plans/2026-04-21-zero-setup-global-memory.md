# Zero-Setup Global Memory Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Global cross-session memory activates automatically after install — no commands required from the user.

**Architecture:** Two changes: `install.sh` creates `~/.claude-task/general/` at the end of install; `bin/claude-task-context` self-heals by recreating it if ever deleted, using an absolute path to avoid PATH issues inside hooks.

**Tech Stack:** Bash, existing `claude-task-init` binary

---

### Task 1: Auto-init global task in `install.sh`

**Files:**
- Modify: `install.sh` (around line 148 — just before the `# 6. Summary` block)

**Step 1: Insert the new step 6 block**

Replace this in `install.sh`:
```bash
ok "Hooks merged"

# 6. Summary
```

With:
```bash
ok "Hooks merged"

# 6. Bootstrap global task memory
step "Creating global task memory"
if [ ! -d "$HOME/.claude-task/general" ]; then
  "$INSTALL_DIR/bin/claude-task-init" general --title "Global session memory" --global \
    && ok "Global task memory ready at ~/.claude-task/general/" \
    || warn "Could not create global task memory — run manually: claude-task-init general --title 'Global session memory' --global"
else
  ok "Global task memory already exists at ~/.claude-task/general/"
fi

# 7. Summary
```

Also update the summary step number comment from `# 6. Summary` to `# 7. Summary` and remove step 3 from the "Next steps" echo block (users no longer need to run claude-task-init manually):

Replace:
```bash
echo "  3. In any repo, run 'claude-task-init <slug> --title \"...\"' to scaffold"
echo "     the first task. Then ask Claude to fill out BRIEF / NEXT / STATUS."
```

With:
```bash
echo "  3. Global memory is active. Claude Code will remember context across sessions"
echo "     automatically. Run 'claude-task-init <slug> --title \"...\"' inside a repo"
echo "     to create project-specific task memory."
```

**Step 2: Verify the script is valid bash**

```bash
bash -n ~/claude-task-templates/install.sh
```
Expected: no output (valid)

**Step 3: Commit**

```bash
cd ~/claude-task-templates
git add install.sh
git commit -m "feat: auto-init global task memory during install"
```

---

### Task 2: Self-heal in `bin/claude-task-context`

**Files:**
- Modify: `bin/claude-task-context` (lines 24–28 — the global fallback block)

**Step 1: Replace the global fallback block**

Replace this in `bin/claude-task-context`:
```bash
# Fall back to global task store (~/.claude-task/) if no repo-local one found.
if [ ! -d "$DIR/.claude-task" ]; then
  [ -d "$HOME/.claude-task" ] || exit 0
  DIR="$HOME"
fi
```

With:
```bash
# Fall back to global task store (~/.claude-task/) if no repo-local one found.
if [ ! -d "$DIR/.claude-task" ]; then
  # Auto-create global task if missing (self-heal).
  if [ ! -d "$HOME/.claude-task" ] || [ ! -f "$HOME/.claude-task/ACTIVE" ]; then
    INIT_BIN="$HOME/claude-task-templates/bin/claude-task-init"
    if [ -x "$INIT_BIN" ]; then
      "$INIT_BIN" general --title "Global session memory" --global >/dev/null 2>&1 || true
    else
      exit 0
    fi
  fi
  [ -d "$HOME/.claude-task" ] || exit 0
  DIR="$HOME"
fi
```

**Step 2: Verify the script is valid bash**

```bash
bash -n ~/claude-task-templates/bin/claude-task-context
```
Expected: no output (valid)

**Step 3: Smoke test — simulate missing global store**

```bash
# Back up and remove global store
mv ~/.claude-task ~/.claude-task.bak 2>/dev/null || true

# Trigger the hook manually (simulates a user prompt)
echo '{}' | ~/claude-task-templates/bin/claude-task-context

# Verify it was recreated
ls ~/.claude-task/ACTIVE && cat ~/.claude-task/ACTIVE
```
Expected: prints `general`

```bash
# Restore backup if you had one
[ -d ~/.claude-task.bak ] && rm -rf ~/.claude-task && mv ~/.claude-task.bak ~/.claude-task
```

**Step 4: Commit**

```bash
cd ~/claude-task-templates
git add bin/claude-task-context
git commit -m "feat: auto-heal global task memory from hook"
```

---

### Task 3: Push and verify

**Step 1: Push both commits**

```bash
cd ~/claude-task-templates
git push origin main
```

**Step 2: End-to-end smoke test of install**

```bash
# Simulate a fresh install by removing the global task
rm -rf ~/.claude-task

# Re-run the installer
curl -fsSL https://raw.githubusercontent.com/ericwang19832003/claude-task-templates/main/install.sh | bash

# Verify global task was created
ls ~/.claude-task/general/
cat ~/.claude-task/ACTIVE
```
Expected: `general`
