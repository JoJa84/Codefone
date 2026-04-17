# SCOPE (v0.2 — Linux Terminal pivot, locked)

Joe approved this scope. Do not re-litigate it.

## Target

- **Device:** Pixel 8+ running Android 15+. Linux Terminal is Pixel-exclusive at the moment. Test fleet: Google Pixel 8 128GB (primary), Galaxy S20 FE 5G 128GB (legacy Termux SKU), Galaxy S23 Ultra 256GB.
- **OS strategy (two paths):**
  - **Path A — Pixel 8+, Android 15+ (primary, recommended):** stock Android flashed via [flash.android.com](https://flash.android.com). Bootloader stays unlocked for reflash safety. **No root. No Termux.** Claude Code runs inside Android's native **Linux Terminal** — an AVF-backed Debian VM with real glibc. Official installer `curl -fsSL https://claude.ai/install.sh | bash` drops `claude` at `~/.local/bin/claude` in the VM.
  - **Path B — Legacy Termux (carrier-locked Samsungs, pre-Android 15 devices):** stock Android as shipped. Bootloader stays locked. Bloatware stripped via `adb shell pm uninstall --user 0 ...`. Claude Code in **Termux**. Retained only for SKUs that can't run the Linux Terminal.
- **Custom ROM:** explicitly rejected. See `DECISIONS.md` D15 (pivot from LineageOS).
- **Root (Magisk):** explicitly rejected. See `DECISIONS.md` D20 — OTA breakage + unnecessary given VM approach.
- **Kiosk strategy:** Screen Pinning + launcher configuration. Full hardened lockdown is v1.

## User experience

- **First boot:** Wizard walks buyer through WiFi → open Linux Terminal → Debian VM auto-provisions → Anthropic OAuth (`claude login`) → keyboard mode (voice-first or Bluetooth keyboard) → sync choice (GitHub or Drive) → done.
- **Normal use:** Unlock phone → tap Linux Terminal icon → VM resumes → shell drops into `~/projects` → type `claude`.
- **Code sync:** `~/projects` inside the VM pushes to the buyer's chosen remote on demand via `devbox sync`. GitHub path is bidirectional (pull + push); Drive path is one-way backup (push only). `~/.claude` stays on-device.
- **Remote control:** SSH from PC works out of the box — Terminal app's port forwarding exposes VM's sshd on Android localhost, `adb forward` or WiFi bridges it to PC.

## Claude Code setup (Path A — Linux Terminal)

- Installed via `curl -fsSL https://claude.ai/install.sh | bash` inside the Debian VM.
- Binary at `~/.local/bin/claude` (native glibc, ~200 MB).
- PATH persisted via `~/.profile` and `~/.bashrc` so both interactive and SSH sessions find it.
- MCP servers preloaded: **filesystem, git, github, web-fetch**.
- Billing: **BYOA** (buyer brings own Anthropic account).

## Path B legacy Termux setup (Samsung only)

- Termux from F-Droid, `npm install -g @anthropic-ai/claude-code`.
- ⚠️ Known issue: Claude Code 2.1.x pre-built binary fails on Termux/Bionic. Fallback workaround: pin to 2.0.x or use `node <entrypoint>` against the JS source. Path B is legacy — prefer Path A for all new units.

## Branding

- Name: **DevBox** for v0. TM risk flagged in `BRAND-RISK.md`.
- Brand string appears in user-visible docs only — never hardcoded into file names or scripts. Rename is cheap.

## What's explicitly NOT in v0

- Custom ROM / LineageOS fork.
- Branded bootscreen / animations.
- Bundled Bluetooth keyboard (future product decision).
- Prepaid API credits / any Anthropic ToS-adjacent billing setup.
- Relocking the bootloader after flashing (would brick Magisk-patched devices).

## Build work sequence (v0.2)

1. Docs foundation (README, SCOPE, HANDOFF, DECISIONS, BRAND-RISK, FLASH) ✅
2. `provision.sh` — Termux install of Node, Claude Code CLI, MCP packages ✅
3. `wizard.sh` — interactive first-boot ✅
4. `mcp-config.json` — preloaded MCP config ✅
5. `sync-github.sh` + `sync-drive.sh` — state sync ✅
6. `kiosk-setup.md` + `reflash-to-stock.md` ✅
7. Fill out `FLASH.md` two-path step-by-step for cousin ⏳
8. Codex adversarial review → fix findings → commit ✅ (v0.1)
9. **Pivot doc pass** — update all docs to reflect stock+Magisk direction ⏳
10. Final polish, update `HANDOFF.md`

## Decision protocol

Joe delegated all build-time decisions. On 50/50 calls: pick the simpler path, ship, note the alternative in `DECISIONS.md`. Do **not** leave a question in `HANDOFF.md` asking Joe — make the call yourself.
