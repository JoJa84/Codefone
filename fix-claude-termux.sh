#!/data/data/com.termux/files/usr/bin/bash
# fix-claude-termux.sh — Patch Claude Code to run on Termux (Android)
#
# Claude Code's install.cjs rejects platform='android' because its PLATFORMS
# map only knows linux/darwin/win32. Termux Node reports 'android'. But
# Termux's Android runtime is compatible with linux-arm64-musl static
# binaries, so we patch platform detection and install the musl variant.

set -euo pipefail

CLAUDE_DIR="$PREFIX/lib/node_modules/@anthropic-ai/claude-code"

echo "==> Patching install.cjs and cli-wrapper.cjs to map android→linux-musl"

# The sed target: getPlatformKey()'s fallback return statement.
# Replace `return platform + '-' + cpu` so android becomes linux-<cpu>-musl.
PATCH_FROM="return platform + '-' + cpu"
PATCH_TO="return (platform === 'android' ? 'linux-' + cpu + '-musl' : platform + '-' + cpu)"

for f in install.cjs cli-wrapper.cjs; do
  if [ -f "$CLAUDE_DIR/$f" ]; then
    if grep -q "platform === 'android'" "$CLAUDE_DIR/$f"; then
      echo "  - $f already patched, skipping"
    else
      sed -i "s|$PATCH_FROM|$PATCH_TO|g" "$CLAUDE_DIR/$f"
      echo "  - patched $f"
    fi
  fi
done

echo "==> Installing @anthropic-ai/claude-code-linux-arm64-musl native dep"
npm install -g --force @anthropic-ai/claude-code-linux-arm64-musl 2>&1 | tail -5

echo "==> Running install.cjs to wire the native binary"
cd "$CLAUDE_DIR"
node install.cjs || true

echo "==> Testing claude --version"
claude --version || echo "(still broken — check errors above)"
