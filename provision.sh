#!/data/data/com.termux/files/usr/bin/bash
#
# Codefone provision.sh
#
# Runs inside Termux on a freshly-flashed Android 12+ phone (Pixel with Magisk
# root or stock-locked Samsung). Installs Node, Python, git, Claude Code CLI,
# and MCP server packages. Idempotent: safe to re-run.
#
# Usage (from Termux):
#   bash provision.sh
#
# Or via ADB from the flashing PC:
#   adb push provision.sh /data/local/tmp/
#   adb shell "run-as com.termux sh -c 'cp /data/local/tmp/provision.sh \$HOME/ && bash \$HOME/provision.sh'"
#
# Exit codes:
#   0 — success
#   1 — not running in Termux
#   2 — package install failed
#   3 — npm install failed
#   4 — pip install failed

set -euo pipefail

# ─── Guardrails ─────────────────────────────────────────────────────────────

if [ ! -d "/data/data/com.termux" ]; then
    echo "ERROR: provision.sh must run inside Termux on the device." >&2
    echo "If you're on your PC, push this file to the device first:" >&2
    echo "  adb push provision.sh /data/local/tmp/" >&2
    exit 1
fi

log() { printf "\033[1;36m[codefone]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[codefone:warn]\033[0m %s\n" "$*"; }
fail() { printf "\033[1;31m[codefone:fail]\033[0m %s\n" "$*" >&2; exit "${2:-1}"; }

CODEFONE_HOME="$HOME/.codefone"
CODEFONE_VERSION="0.1.0"
MARKER_FILE="$CODEFONE_HOME/provisioned"

mkdir -p "$CODEFONE_HOME" "$HOME/projects"

# ─── Storage permission (for ~/storage symlinks into shared storage) ────────

if [ ! -d "$HOME/storage" ]; then
    log "Requesting Android storage permission (grant it when prompted)..."
    termux-setup-storage || warn "termux-setup-storage failed; buyer can grant later"
    sleep 2
fi

# ─── Package manager refresh ────────────────────────────────────────────────

log "Updating Termux package index..."
pkg update -y >/dev/null 2>&1 || fail "pkg update failed" 2
pkg upgrade -y >/dev/null 2>&1 || warn "pkg upgrade had warnings (not fatal)"

# ─── Core packages ──────────────────────────────────────────────────────────

log "Installing core packages..."
# nodejs-lts for Claude Code CLI (Node 20+)
# python for MCP servers that ship as Python packages (git, fetch)
# git/openssh for state sync
# rclone for Drive sync
# termux-api for device integrations (notifications, TTS)
# jq for JSON munging in wizard.sh
CORE_PACKAGES=(
    nodejs-lts
    python
    git
    openssh
    curl
    wget
    rclone
    termux-api
    jq
    nano
    tmux
)

for pkg_name in "${CORE_PACKAGES[@]}"; do
    if pkg list-installed 2>/dev/null | grep -q "^${pkg_name}/"; then
        log "  ✓ ${pkg_name} already installed"
    else
        log "  installing ${pkg_name}..."
        pkg install -y "${pkg_name}" >/dev/null 2>&1 \
            || fail "failed to install ${pkg_name}" 2
    fi
done

# ─── Claude Code CLI ────────────────────────────────────────────────────────

if command -v claude >/dev/null 2>&1; then
    log "Claude Code CLI already installed ($(claude --version 2>/dev/null || echo unknown))"
else
    log "Installing Claude Code CLI (npm global)..."
    # -g installs globally inside Termux's prefix (~/../usr/lib/node_modules)
    npm install -g @anthropic-ai/claude-code >/dev/null 2>&1 \
        || fail "npm install claude-code failed" 3
fi

# ─── MCP server packages ────────────────────────────────────────────────────

log "Installing MCP server packages..."

# Filesystem MCP is mandatory — Claude Code without file access is useless.
log "  installing @modelcontextprotocol/server-filesystem (REQUIRED)..."
if npm list -g --depth=0 2>/dev/null | grep -q "@modelcontextprotocol/server-filesystem"; then
    log "  ✓ filesystem server already installed"
else
    npm install -g "@modelcontextprotocol/server-filesystem" >/dev/null 2>&1 \
        || fail "npm install @modelcontextprotocol/server-filesystem failed — cannot continue" 3
fi

# GitHub server is optional (only useful if user sets up GH sync)
log "  installing @modelcontextprotocol/server-github..."
if npm list -g --depth=0 2>/dev/null | grep -q "@modelcontextprotocol/server-github"; then
    log "  ✓ github server already installed"
else
    npm install -g "@modelcontextprotocol/server-github" >/dev/null 2>&1 \
        || warn "github server install failed (optional, wizard will skip this MCP)"
fi

# Python-based MCP servers. Both optional — pydantic-core (a dependency) requires
# Rust compilation, which fails on Termux's aarch64-unknown-linux-android target.
# Claude Code has built-in git and web-fetch tools, so these MCPs are nice-to-have.
for srv in "mcp-server-git"; do
    if pip show "${srv}" >/dev/null 2>&1; then
        log "  ✓ ${srv} already installed"
    else
        log "  installing ${srv} (optional — Claude Code has built-in git)..."
        pip install --quiet --no-input "${srv}" \
            || warn "pip install ${srv} failed (pydantic-core needs Rust, which Termux can't build). Skipping — Claude Code's built-in git tools will be used instead."
    fi
done

for srv in "mcp-server-fetch"; do
    if pip show "${srv}" >/dev/null 2>&1; then
        log "  ✓ ${srv} already installed"
    else
        log "  installing ${srv}..."
        pip install --quiet --no-input "${srv}" \
            || warn "pip install ${srv} failed (optional, wizard will skip this MCP)"
    fi
done

# Note: mcp-config.json in this repo is a reference document. Claude Code's
# actual MCP state lives in ~/.claude.json and is managed by wizard.sh via
# `claude mcp add` commands. We do not copy mcp-config.json anywhere here.

# ─── codefone helper command ──────────────────────────────────────────────────

log "Installing 'codefone' helper command..."
CODEFONE_BIN="$PREFIX/bin/codefone"
cat > "$CODEFONE_BIN" << 'CODEFONE_EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Codefone helper — update / sync / reflash / status
set -euo pipefail

CODEFONE_HOME="$HOME/.codefone"
CODEFONE_CMD="${1:-help}"

case "$CODEFONE_CMD" in
    update)
        echo "[codefone] updating Claude Code and MCP servers..."
        npm update -g @anthropic-ai/claude-code
        npm update -g @modelcontextprotocol/server-filesystem \
                      @modelcontextprotocol/server-github
        pip install --quiet --upgrade mcp-server-git mcp-server-fetch
        echo "[codefone] update complete."
        ;;
    sync)
        METHOD=$(cat "$CODEFONE_HOME/sync-method" 2>/dev/null || echo "none")
        case "$METHOD" in
            github)  bash "$CODEFONE_HOME/sync-github.sh" ;;
            drive)   bash "$CODEFONE_HOME/sync-drive.sh" ;;
            none)    echo "[codefone] no sync method configured. Run 'codefone wizard' to set up." ;;
            *)       echo "[codefone] unknown sync method: $METHOD" ;;
        esac
        ;;
    wizard)
        bash "$CODEFONE_HOME/wizard.sh"
        ;;
    status)
        echo "Codefone version:    $(cat "$CODEFONE_HOME/version" 2>/dev/null || echo unknown)"
        echo "Claude Code:       $(claude --version 2>/dev/null || echo 'NOT INSTALLED')"
        echo "Node:              $(node --version 2>/dev/null || echo 'NOT INSTALLED')"
        echo "Python:            $(python --version 2>/dev/null || echo 'NOT INSTALLED')"
        echo "Sync method:       $(cat "$CODEFONE_HOME/sync-method" 2>/dev/null || echo 'not configured')"
        echo "Projects dir:      $HOME/projects"
        ;;
    reflash)
        echo "[codefone] reflash-to-stock instructions live in the docs shipped with the device."
        echo "See $CODEFONE_HOME/reflash-to-stock.md (if present) or the repo on GitHub."
        ;;
    help|*)
        echo "Codefone helper commands:"
        echo "  codefone update    — update Claude Code and MCP servers"
        echo "  codefone sync      — push/pull state to configured remote"
        echo "  codefone wizard    — re-run the first-boot wizard"
        echo "  codefone status    — show installed versions and config"
        echo "  codefone reflash   — point at reflash-to-stock instructions"
        ;;
esac
CODEFONE_EOF
chmod +x "$CODEFONE_BIN"

# ─── Termux:Boot integration ────────────────────────────────────────────────
# If Termux:Boot is installed, drop a script in ~/.termux/boot/ so the wizard
# (or claude) launches on device boot.

BOOT_DIR="$HOME/.termux/boot"
mkdir -p "$BOOT_DIR"

cat > "$BOOT_DIR/01-codefone-autostart.sh" << 'BOOT_EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Runs on boot if Termux:Boot is installed.
# Keeps CPU awake during provisioning / setup, then hands off to the wizard
# or Claude Code on subsequent boots.

termux-wake-lock

if [ ! -f "$HOME/.codefone/provisioned" ]; then
    # Not yet set up — do nothing; user will open Termux manually to finish.
    exit 0
fi

if [ ! -f "$HOME/.codefone/wizard-done" ]; then
    # Provisioned but wizard not completed — run wizard on next Termux open.
    exit 0
fi

# All set up — start a detached tmux session so Claude Code is ready
# when the buyer opens Termux.
tmux has-session -t codefone 2>/dev/null || \
    tmux new-session -d -s codefone "cd ~/projects && claude || bash"
BOOT_EOF
chmod +x "$BOOT_DIR/01-codefone-autostart.sh"

# ─── Termux login / welcome ─────────────────────────────────────────────────

# Replace the default Termux motd with a Codefone welcome. Runs on every new
# Termux session.

cat > "$HOME/.bashrc" << 'BASHRC_EOF'
# Codefone bashrc
[ -f "$PREFIX/etc/profile" ] && . "$PREFIX/etc/profile" 2>/dev/null || true

export PATH="$HOME/.local/bin:$PATH"
export EDITOR=nano
export PAGER=less

# First-time wizard auto-run
if [ -f "$HOME/.codefone/provisioned" ] && [ ! -f "$HOME/.codefone/wizard-done" ]; then
    bash "$HOME/.codefone/wizard.sh"
fi

# Attach to Claude Code session if running
if [ -f "$HOME/.codefone/wizard-done" ] && [ -z "${TMUX:-}" ]; then
    if tmux has-session -t codefone 2>/dev/null; then
        exec tmux attach -t codefone
    else
        cd ~/projects
        exec tmux new-session -s codefone "claude || bash"
    fi
fi

# Plain shell fallback
cd ~/projects 2>/dev/null || cd ~
BASHRC_EOF

# Clear the default Termux motd
: > "$PREFIX/etc/motd"

# ─── Mark provisioned ───────────────────────────────────────────────────────

echo "$CODEFONE_VERSION" > "$CODEFONE_HOME/version"
date -u +"%Y-%m-%dT%H:%M:%SZ" > "$MARKER_FILE"

# Copy wizard.sh and sync scripts into ~/.codefone/ if they're alongside this script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
for f in wizard.sh sync-github.sh sync-drive.sh reflash-to-stock.md; do
    if [ -f "$SCRIPT_DIR/$f" ]; then
        cp "$SCRIPT_DIR/$f" "$CODEFONE_HOME/$f"
        [ "${f##*.}" = "sh" ] && chmod +x "$CODEFONE_HOME/$f"
    fi
done

log ""
log "Provisioning complete."
log ""
log "Next steps:"
log "  1. Reboot the device (or open a fresh Termux session)"
log "  2. The first-boot wizard will run automatically"
log "  3. Run 'codefone status' any time to check state"
log ""
log "To re-run the wizard manually: codefone wizard"
