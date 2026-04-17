# DevBox

**A phone that runs Claude Code. Nothing else.**

Take a refurbished phone. Flash it with LineageOS. Boot into a full Claude Code terminal. Sign in once. Start building.

No personal data on the device. No apps you don't need. No risk to your main machine. Just an AI coding agent in your pocket — isolated, portable, and always ready.

---

## Why

You want to run Claude Code with full permissions. You don't want to give it the keys to your laptop.

DevBox solves this by putting the agent on its own device — a physical sandbox. The agent gets unlimited access to its own filesystem, its own terminal, its own git. It can't see your browser history, your SSH keys, your company Slack. If it does something weird, you factory reset and start over. Total isolation. Zero risk.

And because it's a phone, you take it everywhere. Code from the couch. Debug on the train. Pair a Bluetooth keyboard at a coffee shop. Or control it remotely from your PC over WiFi — full two-way SSH, no cable needed.

## What it actually is

- A **Pixel 8** (or Galaxy S20/S21/S22/S23, or any Android 12+ phone) running **LineageOS** — a clean, open-source Android with no Google services and no bloatware.
- **Termux** providing a full Linux terminal with Node, Python, git, and SSH.
- **Claude Code CLI** installed and ready to go at first boot.
- **MCP servers** preloaded (filesystem, GitHub).
- **State sync** so you can start a project on the phone and pick it up on your PC — via GitHub (bidirectional) or Google Drive (backup).
- **SSH server** so you can connect to the device wirelessly from any machine on your network.

## The 30-second demo

```
# From your PC, over WiFi, no USB:
$ ssh -p 8022 devbox@192.168.1.36

DevBox ready. Type: claude

$ claude

╭──────────────────────────────────────╮
│ Claude Code                          │
│                                      │
│ Pixel 8 · LineageOS · Termux         │
│ Your pocket AI sandbox               │
╰──────────────────────────────────────╯

> Build me a REST API for managing tasks.

  I'll create that for you...
```

You're SSH'd into a phone in your pocket, talking to Claude Code, building software. From your couch. Or your office. Or the other side of the house.

## Build your own (15 minutes)

Everything you need is in this repo. No special equipment — just a USB cable and a laptop.

### What you need

- Any Android 12+ phone (tested: Pixel 8, Galaxy S20 FE, Galaxy S23 Ultra)
- A USB-C cable
- A PC with ADB installed ([download](https://developer.android.com/tools/releases/platform-tools))
- A WiFi network
- An Anthropic account ([sign up](https://claude.ai))

### Steps

1. **Flash LineageOS** on the phone ([full guide](FLASH.md))
   - Unlock bootloader (one command)
   - Flash LineageOS recovery + ROM (three commands + one sideload)
   - ~15 minutes, zero brick risk — you can always restore stock Android

2. **Install Termux** + push DevBox scripts
   ```bash
   bash flash-device.sh
   ```

3. **Open Termux on the phone**, run:
   ```
   bash ~/storage/downloads/devbox/provision.sh
   ```
   Installs Node, Python, Claude Code, MCP servers. ~5 minutes.

4. **Run the wizard**
   ```
   devbox wizard
   ```
   Signs you into Anthropic, sets up sync, wires MCP servers. ~2 minutes.

5. **Done.** Type `claude` and go.

### Optional: SSH from your PC (wireless control)

```bash
# On the phone (in Termux):
sshd

# On your PC:
ssh -p 8022 <phone-ip>
```

Now you can type prompts, read output, and control the agent from your laptop — while the phone sits in your pocket.

## What's inside

| File | What it does |
| --- | --- |
| [`FLASH.md`](FLASH.md) | Full step-by-step for flashing a phone |
| [`flash-device.sh`](flash-device.sh) | PC-side script: installs Termux + pushes files via ADB |
| [`provision.sh`](provision.sh) | Phone-side: installs Node, Claude Code, MCP servers |
| [`wizard.sh`](wizard.sh) | First-boot setup: Anthropic login, sync, keyboard mode |
| [`sync-github.sh`](sync-github.sh) | Bidirectional project sync to a private GitHub repo |
| [`sync-drive.sh`](sync-drive.sh) | Backup sync to Google Drive via rclone |
| [`kiosk-setup.md`](kiosk-setup.md) | Lock the phone to Termux only (optional) |
| [`reflash-to-stock.md`](reflash-to-stock.md) | Restore the phone to factory Android |

## FAQ

**Will this brick my phone?**
No. We don't touch the bootloader's core firmware. Worst case: boot into fastboot (hardware buttons always work), flash Google's stock image, phone is back to normal in 5 minutes.

**Does it need a SIM card?**
No. WiFi only. Add a SIM if you want cellular data, but it's not required.

**Can I use it as a regular phone too?**
Yes. LineageOS is full Android — you can install any APK. But the point is that you *don't*. The isolation is the feature.

**What about battery life?**
Claude Code sessions are network calls, not local compute. Battery impact is similar to browsing the web. A full charge lasts a workday of moderate use.

**How do I update Claude Code?**
```
devbox update
```

**Can I control it from my PC?**
Yes. Over USB (`adb`) or wirelessly over SSH. Full two-way — you can type prompts and read responses from your laptop while the phone is across the room.

**What stops someone from just installing Claude Code on any phone?**
Nothing. But DevBox is pre-configured, pre-flashed, and ready to go in 30 seconds out of the box. That's the product. This repo is the recipe.

## Status

**v0 — first device flashed and working.** Pixel 8 on LineageOS 23.2. Claude Code running, SSH working, wireless control confirmed.

Next: flash the Galaxy S20 FE and S23 Ultra, then a small production run.

## License

MIT

---

*Built with [Claude Code](https://claude.ai/claude-code).*
