# HANDOFF — Session-to-session pickup

**Last updated:** 2026-04-19 — Pixel 8 reference unit: voice I/O unblocked, Claude Code now runs in bypass-permissions mode with sudo available. Confirmed end-to-end from PC.

**Current status:** **v0.2 shipping stance locked.**
- **Galaxy S20 FE (Verizon, Path B legacy):** ✅ stock + bloatware-stripped, Claude Code 2.0.x via Termux, SSH on 8022, OpenBrain MCP wired. Kept only as legacy SKU — Claude 2.1.x incompatible with Termux/Bionic.
- **Pixel 8 (Path A, primary):** ✅ stock Android 16 + Linux Terminal + Debian VM, ✅ Claude Code **2.1.114** native, ✅ PATH persisted, ✅ SSH from PC via nc relay on 2223 (Terminal's built-in forwarder is flaky — see FLASH.md §A6), ✅ `android.permission.RECORD_AUDIO` granted, mic verified live (RMS > 0.004 on ambient capture), ✅ voice pipeline built (`~/bin/v` whisper.cpp + `~/bin/say` espeak-ng + Stop hook), ✅ Claude `settings.local.json` → `defaultMode: bypassPermissions`, ✅ droid has `NOPASSWD: ALL` sudo, Magisk uninstalled per D20.
- **Galaxy S23 Ultra:** not started.

## Next actions, in priority order

1. **First production Pixel 8 complete** (this unit is now the golden reference build). Remaining polish:
   - `claude login` OAuth flow — walk through it once on this unit, document any snags.
   - Confirm `claude` interactive UI renders OK on Pixel 8's 6.2" screen at default font.
   - Disable auto-OTAs on this reference unit: Settings → System → Software update → Auto-download OFF (avoid the OTA-slot-flip quirk).
2. **Write `codefone revive` script** — one-tap `am force-stop com.android.virtualization.terminal` + relaunch to cure "Preparing terminal" hang. Ship as an ADB-invokable script AND as an on-device shortcut.
3. **MCP wiring inside the Debian VM** — filesystem, git, github, web-fetch. Need to register via `claude mcp add --scope user`. Test each.
4. **Path B bloatware-strip script** — consolidate 195 commands into `strip-bloat-s20.sh`.
5. **Galaxy S23 Ultra** — acquire, repeat Path A if it's on Android 15+ with Linux Terminal available, else Path B.
6. **Production run prep** — decide batch size (10? 20?), finalize logo, write eBay/Skool listing copy.

## Blockers for shipping a production run

- [ ] `claude login` + first real session validated on Pixel 8.
- [ ] `codefone revive` script written and tested.
- [ ] MCP servers wired inside the Debian VM.
- [ ] `strip-bloat-s20.sh` checked in (Path B only).
- [ ] Logo selected (5 options generated, none chosen).
- [ ] Real-world smoke test on one fully-provisioned reference device.

## What happened in this session (2026-04-17)

1. Resumed from dropped session. Read `project:codefone` from Open Brain.
2. Flashed Pixel 8 → rooted with Magisk v30.7 (slot B). Confirmed root.
3. Installed Termux + provisioning scripts. Ran `provision.sh`. Node + Python + Claude Code CLI via npm.
4. **Claude Code binary failed to exec** — Termux Node reports `platform=android`, Claude's native binary (`@anthropic-ai/claude-code-linux-arm64-musl`) expects a musl linker Bionic doesn't have. Wrote `fix-claude-termux.sh` to patch platform detection + install the musl variant; installer progressed but binary still ENOENT on exec.
5. **Pivoted to Android's native Linux Terminal** (Debian VM via AVF) at Joe's suggestion. Enabled Developer Options → Linux development environment. Downloaded 565 MB rootfs.
6. **Installed Claude Code natively via official installer** inside VM: `curl -fsSL https://claude.ai/install.sh | bash` → `2.1.113 (Claude Code)`. Worked first try.
7. Persisted PATH in `.bashrc` and `.profile`. Survived phone reboot.
8. Installed `openssh-server`, set up authorized_keys with PC's ed25519 key, added `Port 2222` to sshd_config. Joe enabled port 2222 in Terminal app's port forwarding UI.
9. `adb forward tcp:2222 tcp:2222` → `ssh -p 2222 droid@127.0.0.1` → **works from PC**.
10. Noticed Magisk showed "Installed: N/A" after reboot. Diagnosed: Android OTA applied to inactive slot A, reboot flipped to A, Magisk on slot B was orphaned. Confirmed this is the standard A/B + OTA interaction.
11. **Decided to drop Magisk entirely** (D20). Uninstalled the Magisk Android app. Slot B patched init_boot is harmless — next OTA will overwrite it.
12. Rewrote docs for Linux Terminal direction. (This commit.)

## Key learnings baked into docs

- **Linux Terminal > Termux for Pixel** (D19) — glibc + official installer > Bionic + broken platform detection.
- **Magisk dropped** (D20) — unnecessary given VM approach, OTAs break it monthly.
- **"Preparing terminal" spinner hang** — known AVF bug. Force-stop + relaunch.
- **Port 2222 in Terminal app's port forwarding UI + `adb forward` = SSH from PC.** No Magisk/iptables needed.
- **Screen-lock can kill the VM** — set long timeout or keep phone plugged in + `svc power stayon true`.
- **OTAs apply to inactive slot** — standard Android A/B behavior. Had been silently reverting root; moot now that we've dropped Magisk.

## Key files and artifacts

| Artifact | Location | Purpose |
| --- | --- | --- |
| Repo | `R:\Projects\ai-phone-agent` + `github.com/JoJa84/Codefone` | Source of truth |
| ADB/fastboot | `C:\platform-tools` | Device communication |
| Factory image (shiba) | `R:\Downloads\Delete Later\shiba-factory.zip` | Stock Android 16 for Pixel 8 reflash |
| Joe's PC SSH key | `C:\Users\Joe\.ssh\id_ed25519(.pub)` | Installed in VM's authorized_keys |
| Open Brain canonical | `project:codefone` (ID 2292161) | Long-term memory — needs update for D19/D20 |

## Protocol for any continuation sessions

1. **Check Open Brain** — `memory_search "project:codefone"` returns canonical state.
2. **Read `SCOPE.md`** — locked v0.2 scope, Linux Terminal direction.
3. **Read `DECISIONS.md`** — D1–D20. D19 (Linux Terminal pivot) and D20 (drop Magisk) are the latest.
4. **Check `git log --oneline -20`** — see what's been committed.
5. **Do the next item** — see "Next actions" above.
6. **Before ending the session, update this file AND the Open Brain entry.**
7. **Commit atomically** using conventional commits.

## Rules that still apply

- Joe is not a developer. Decide and execute. No technical branching questions.
- On 50/50 decisions: pick the simpler path, ship it, record in `DECISIONS.md`.
- Do not break working code. `bash -n <script>` before committing.
- Pixel path is primary. Samsung/Termux path is legacy — only touch if asked.
