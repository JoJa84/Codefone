# DevBox

**A phone that runs Claude Code. Nothing else.**

Take a Pixel. Flash it with stock Android. Open the native Linux Terminal. Install Claude Code. Boot into a full AI coding sandbox in your pocket.

No personal data on the device. No Termux. No root. No clutter. Just Claude Code on a real Debian VM — isolated from your main machine, always in your pocket.

---

## Why

You want to run Claude Code with full permissions. You don't want to give it the keys to your laptop.

DevBox solves this by putting the agent on its own device — a physical sandbox. The agent gets unlimited access to its own filesystem, its own terminal, its own git. It can't see your browser history, your SSH keys, your company Slack. If it does something weird, you factory reset and start over. Total isolation. Zero risk.

And because it's a phone, you take it everywhere. Code from the couch. Debug on the train. Pair a Bluetooth keyboard at a coffee shop. Or control it remotely from your PC over WiFi — full two-way SSH, no cable needed.

## What it actually is

- A **Pixel 8** (or any Pixel on Android 15+) running **stock Android** — unrooted, unmodified. Real Android. Security updates included.
- **Android's native Linux Terminal** — the AVF-backed Debian VM that ships with Android 15+. Real glibc. Full `apt`. No Termux.
- **Claude Code CLI** installed via the official native installer (`curl -fsSL https://claude.ai/install.sh | bash`) at `~/.local/bin/claude` inside the VM.
- **SSH server** so you can connect to the VM wirelessly from any machine on your network.
- **State sync** — `~/projects` inside the VM syncs to GitHub (bidirectional) or Google Drive (one-way backup).

## The 30-second demo

```
# From your PC, over WiFi, no USB:
$ ssh -p 2222 droid@192.168.1.65

droid@debian:~$ claude

╭──────────────────────────────────────╮
│ Claude Code 2.1.113                  │
│                                      │
│ Pixel 8 · Debian VM on Android 16    │
│ Your pocket AI sandbox               │
╰──────────────────────────────────────╯

> Build me a REST API for managing tasks.

  I'll create that for you...
```

You're SSH'd into a Debian VM on a phone in your pocket, talking to Claude Code, building software. From your couch. Or your office. Or the other side of the house.

## Build your own (15 minutes)

Everything you need is in this repo. No special equipment — just a USB cable and a laptop with Chrome/Edge.

### What you need

- A **Pixel 8 or newer** (required — Linux Terminal is Pixel-only as of Android 16)
- A USB-C cable
- A PC with ADB installed ([download](https://developer.android.com/tools/releases/platform-tools))
- A WiFi network
- An Anthropic account ([sign up](https://claude.ai))
- Chrome or Edge (for [flash.android.com](https://flash.android.com))

### Steps

1. **Flash the phone to clean stock Android** ([full guide](FLASH.md))
   - Open [flash.android.com](https://flash.android.com) in Chrome/Edge.
   - Select your Pixel → latest stable build → Wipe Device ON, Force Flash all Partitions ON, Lock Bootloader OFF.
   - ~15 min. Phone reboots into Android setup.

2. **Enable Linux Terminal**
   - Settings → About phone → tap Build number 7× → Developer options.
   - Settings → System → Developer options → **Linux development environment** → toggle **On**.
   - Open the Linux Terminal app → it downloads a ~565 MB Debian rootfs.

3. **Install Claude Code inside the Debian VM**
   - Open Terminal app. At the `droid@debian:~$` prompt:
     ```
     curl -fsSL https://claude.ai/install.sh | bash
     echo 'export PATH=$HOME/.local/bin:$PATH' >> ~/.bashrc
     source ~/.bashrc
     claude --version
     ```
   - Should print `2.1.113 (Claude Code)` or newer.

4. **Sign in + go**
   - `claude login` → follow browser OAuth prompt → done.
   - `claude` → start building.

### Optional: SSH from your PC (wireless control)

Inside the VM:
```
sudo apt install -y openssh-server
echo "Port 2222" | sudo tee -a /etc/ssh/sshd_config
sudo systemctl enable --now ssh
mkdir -p ~/.ssh && echo '<your-public-key>' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys
```

In the Terminal app's settings → **Port forwarding** → add **2222**.

From your PC:
```bash
adb forward tcp:2222 tcp:2222
ssh -p 2222 droid@127.0.0.1
```

Or over WiFi once the phone has a stable LAN IP: `ssh -p 2222 droid@<phone-ip>`.

## What's inside

| File | What it does |
| --- | --- |
| [`FLASH.md`](FLASH.md) | Step-by-step for turning a fresh Pixel into a DevBox |
| [`SCOPE.md`](SCOPE.md) | Locked v0.2 scope — what's in, what's out |
| [`DECISIONS.md`](DECISIONS.md) | Build-time tradeoffs and why |
| [`kiosk-setup.md`](kiosk-setup.md) | Screen-pin + hide other apps for a single-purpose feel |
| [`reflash-to-stock.md`](reflash-to-stock.md) | Restore the phone to factory Android |
| `sync-github.sh` · `sync-drive.sh` | Legacy — bidirectional state sync helpers (carried over from Termux path) |
| `provision.sh` · `flash-device.sh` · `wizard.sh` | Legacy — Termux-based provisioning for Path B devices only |

## FAQ

**Will this brick my phone?**
No. On Pixels, the bootloader stays unlocked and the A/B slot system gives us a bailout lane. Worst case: re-run `flash.android.com` — back to stock in 15 minutes.

**Why Pixel-only?**
Android's Linux Terminal is a Google-specific feature shipped with Pixel's AVF stack. Samsung and other OEMs don't yet expose it. We expect broader support in late 2026 and will add devices as they land.

**Why not Termux?**
Claude Code 2.1.x's pre-built native binary requires a musl dynamic linker that Termux's Bionic libc can't provide. Termux works for Claude 2.0.x via `node ./cli.js`, but that's a fragile hack. The Debian VM gives us real glibc and Claude's official installer works in one command. See `DECISIONS.md` D19.

**Why no root / Magisk?**
The Debian VM gives us full root inside a sandboxed guest — no Android-side privilege escalation needed. Magisk also silently breaks after every monthly OTA on Pixel, which makes it a support nightmare for a product that should "just work." See `DECISIONS.md` D20.

**Does it need a SIM card?**
No. WiFi only. Add a SIM if you want cellular data, but it's not required.

**Can I use it as a regular phone too?**
Yes — it's full Android, you can install any APK. But the point is that you *don't*. The isolation is the feature.

**What about battery life?**
Claude Code sessions are network calls, not local compute. Battery impact is similar to browsing the web. A full charge lasts a workday of moderate use. The Debian VM idles cheap — ~1 GB RAM floor, minimal CPU when not typing.

**How do I update Claude Code?**
Inside the VM: `claude update` (official self-updater).

**Can I control it from my PC?**
Yes. Over USB (`adb forward` + `ssh`) or wirelessly over SSH once you know the phone's LAN IP.

**What about "Preparing terminal" hanging forever?**
Known Android 15/16 quirk — the VM's `virtualizationservice` wedges when the screen locks mid-session. Fix: force-stop the Terminal app (long-press icon → App info → Force stop) and reopen. Takes 5 seconds. We're scripting a `devbox revive` one-tap recovery for v0.3.

## Status

**v0.2 — Pixel 8 shipping on stock Android + Linux Terminal VM.**
- **Pixel 8:** ✅ stock Android 16 flashed, ✅ Linux Terminal enabled, ✅ Claude Code 2.1.113 native + SSH + PC access confirmed. Ready for replication.
- **Galaxy S20 FE (Verizon):** legacy Termux SKU — works for Claude 2.0.x only. Not the primary path.
- **Galaxy S23 Ultra:** not started.

Next: small production run on Pixel 8 stock, eBay/Skool listings.

## License

MIT

---

*Built with [Claude Code](https://claude.ai/claude-code).*
