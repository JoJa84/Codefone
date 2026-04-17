# DevBox

### Your AI agent. In your pocket. For $100.

Not on a $3,000 home rig you SSH into from the couch.
Not behind a Telegram bot proxying to a cloud VM.
Not on a rented GPU server you're paying for by the hour.

**An actual AI agent, actually living in a phone, that you actually carry with you.**

---

## The 60-second pitch

A refurb Pixel 8 costs about $100. It already has:

- A 4nm ARM SoC, 8 GB of RAM, a 4500 mAh battery, 5G, WiFi 6E, GPS, a camera
- A hardware-secured TPM (Titan M2)
- USB-C with host mode
- **A Linux Terminal app shipped by Google, running a real Debian VM**

That last one is new, hiding in Developer Options, and I think almost nobody's realized what it unlocks yet.

You enable it. You run `curl -fsSL https://claude.ai/install.sh | bash`. You sign in. You now have **Claude Code, natively, in your pocket**. No Termux hacks. No custom ROM. No root. No cloud relay. No Telegram duct tape.

A month ago, the cheapest respectable "AI coding rig" was a mini-PC, a Framework, or a used ThinkPad — call it $600–$3,000. DevBox is a $100 phone that fits in your jeans.

## And here's the part that got me out of bed

The phone has a USB-C port.

Once Claude Code is sitting at a root shell inside a Debian VM on this phone, **the phone stops being a phone**. It becomes a universal diagnostic and control surface for whatever you plug into it:

- Plug in a router → Claude configures your router
- Plug in an Arduino / ESP32 → Claude flashes your firmware
- Plug in an OBD-II adapter → Claude reads your car's engine codes
- Plug in an HVAC service tool → Claude diagnoses the AC unit in your basement
- Plug in a USB-to-serial → Claude talks to any piece of industrial gear
- Plug in a switch or NAS → the IT guy is now walking the building with his whole rig in his pocket

And scale that one step further: **a cheap phone running a purpose-built VM image becomes a specialty device for any vertical.** Field tech. Bench instrument. Inventory scanner. POS terminal. Kiosk. Lab controller. The phone is just the shell. The VM is the product.

That's the part I can't stop thinking about. I'd love other people to think about it too.

---

## What it actually is, technically

- **Pixel 8 or newer** (Pixel-only for now — Linux Terminal is Google's AVF stack; Samsung etc. don't expose it yet)
- **Stock Android 15+** — unrooted, unmodified, OTA updates intact
- **Android's built-in Linux Terminal app** — a real Debian VM via Android Virtualization Framework. Real glibc, real `apt`, real systemd, real root-in-guest
- **Claude Code CLI**, installed via Anthropic's official installer inside the VM
- **SSH** from your PC over WiFi so you can type from a real keyboard with the phone in your pocket
- **~15 min setup, end to end**

No bootloader unlock. No Magisk. Nothing you can brick. Factory reset = clean slate in 5 minutes.

## 30-second demo

```bash
# From your PC, over WiFi:
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

You're SSH'd into a Debian VM on a phone in your pocket, talking to Claude Code, building software. From your couch. Or your office. Or the other side of the house. Or the car.

## Build your own (15 minutes)

You need:

- Pixel 8 or newer (refurb is fine)
- USB-C cable, WiFi, a PC with Chrome/Edge and ADB
- An Anthropic account

Steps:

1. **Flash the phone to clean stock Android.** Open [flash.android.com](https://flash.android.com), select your Pixel, Wipe + Force Flash, leave bootloader locked. ~15 min. Full walkthrough in [FLASH.md](FLASH.md).
2. **Enable Linux Terminal.** Settings → About phone → tap Build number 7× → Developer options → Linux development environment → On. Open the Terminal app. It downloads ~565 MB Debian rootfs.
3. **Install Claude Code inside the VM:**
   ```bash
   curl -fsSL https://claude.ai/install.sh | bash
   echo 'export PATH=$HOME/.local/bin:$PATH' >> ~/.bashrc && source ~/.bashrc
   claude login
   claude
   ```
4. **(Optional) SSH from your PC:** `sudo apt install -y openssh-server`, bind port 2222, add your key, forward the port in the Terminal app's settings, and `ssh -p 2222 droid@<phone-ip>` from your laptop.

That's it. Full docs in [FLASH.md](FLASH.md) and [DECISIONS.md](DECISIONS.md).

## What's inside

| File | What it does |
| --- | --- |
| [`FLASH.md`](FLASH.md) | Step-by-step Pixel → DevBox |
| [`SCOPE.md`](SCOPE.md) | What's in v0.2, what's not |
| [`DECISIONS.md`](DECISIONS.md) | Build-time tradeoffs and why (D1–D20) |
| [`kiosk-setup.md`](kiosk-setup.md) | Screen-pin + hide apps for single-purpose feel |
| [`reflash-to-stock.md`](reflash-to-stock.md) | Restore to factory Android |

## FAQ

**Will this brick my phone?** No. Bootloader stays locked, OTA updates keep working, worst case is a factory reset.

**Why Pixel-only?** Android's Linux Terminal is a Google-specific AVF feature. Samsung and other OEMs haven't shipped it yet. Expecting broader support late 2026.

**Why not Termux?** Claude Code 2.1's native binary needs a libc Termux can't provide (bionic vs musl/glibc ABI mismatch). Real Debian via AVF makes the official installer just work. See D19.

**Why no root / Magisk?** The VM is already a root sandbox. Magisk on the host silently breaks on monthly OTAs. We dropped it. See D20.

**Battery?** Claude is network-bound, not compute-bound. A full charge lasts a workday of moderate use.

**Control from PC?** Yes — `adb forward` + `ssh` over USB, or direct SSH over WiFi.

**"Preparing terminal" hangs?** Known AVF quirk when the screen locks mid-session. Force-stop the Terminal app and reopen. Scripting a one-tap recovery for v0.3.

## Status

**v0.2 — Pixel 8 reference build shipping.**
Stock Android 16 + Linux Terminal VM + Claude Code 2.1.113 native + SSH + PC access, all confirmed on a live unit.

Next up: a `devbox revive` script for the AVF wedge, MCP wiring inside the VM, maybe a small production run.

## I'd love help with

I'm a hobbyist, not a developer. If you see things in this repo that are wrong, short-sighted, or way less ambitious than they should be — please open an issue or a PR. In particular:

- **USB-C peripheral passthrough into the AVF guest** — how deep can we go? OBD-II readers, serial consoles, flash programmers, audio/video capture?
- **VM images as product** — what does a "DevBox image for HVAC techs" or "DevBox image for network admins" actually contain?
- **Security model** — where are the cracks in isolating the guest from the host's contacts/photos/etc.?
- **Older Pixels / other OEMs** — any clean way to backport this to pre-AVF hardware?

If any of that interests you, say hi.

## License

MIT

---

*Built with [Claude Code](https://claude.ai/claude-code).*
