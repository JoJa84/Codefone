# Reddit post drafts

Two versions, pick whichever sub fits your mood. **Not recommending r/LocalLLaMA** — Claude Code is cloud-API, not local inference; that sub will downvote as off-topic.

---

## Version A — r/ClaudeAI (recommended primary target)

**Title:** I got Claude Code running natively on a $100 refurb Pixel 8 — here's how, and the part that actually got me excited

**Body:**

Hobbyist, not a developer. Spent the weekend on this and wanted to share.

**What I did:**

Bought a refurb Pixel 8 for about $100. Flashed clean stock Android 16 via flash.android.com (bootloader stays locked, OTAs keep working). Enabled **Linux Terminal** in Developer Options — this is the thing most people don't know about: Android 15+ ships a real Debian VM built into the OS, backed by the Android Virtualization Framework. Glibc, apt, systemd, root-in-guest. Google shipped it quietly.

Inside that VM, I ran:

```
curl -fsSL https://claude.ai/install.sh | bash
claude login
claude
```

Fifteen minutes later I had **Claude Code 2.1.114 running natively on a phone in my pocket**. SSH'd from my laptop over WiFi. Full keyboard, full Claude Code, the whole experience.

**Why not Termux?** Tried that first. Claude Code 2.1's prebuilt binary expects a musl linker; Termux's Bionic libc can't load it. Patching around it got the install past the platform check but the binary still couldn't exec. The Linux Terminal VM bypasses all of that because it's a real Debian rootfs with real glibc — the official installer just works.

**Voice I/O works too** — whisper.cpp for input, espeak-ng for output, a Stop hook to tie them together. I can literally talk to Claude Code while walking.

**The part that actually got me excited isn't the phone.** It's the USB-C port.

Once you have a rooted shell in a real Debian guest in your pocket, the phone stops being a phone. It becomes a universal diagnostic/control surface for whatever you plug into it:

- Plug in an Arduino → Claude flashes firmware
- Plug in an OBD-II reader → Claude reads your car's engine codes
- Plug in a USB-serial cable → Claude talks to industrial gear
- Plug in a router → Claude configures your router

A $100 phone + a curated VM image becomes a specialty field device for any vertical. The VM is the product. The phone is just the shell.

**State of the world:** v0.2, reference unit on my desk. Open repo, source-available under PolyForm Noncommercial (free for personal/non-commercial; commercial license separate). Rough edges I'm honest about: a "Preparing terminal" spinner bug when the screen locks mid-session, MCP servers not yet wired inside the Debian guest, a one-tap recovery script still on the TODO list.

**Related work, positioned honestly:** Sealos DevBox, AgentOS, Anthropic's own Remote Control (shipped Feb 2026) — all cloud or tethered-laptop. This is the standalone on-device variant. Nobody else seems to be shipping this shape.

**What I'd love help with:**

- USB-C peripheral passthrough into the AVF guest — how deep can we go?
- Vertical VM images — what does "Codefone for HVAC techs" actually contain?
- Security model — where are the cracks between Android host and Debian guest?
- Older Pixels / non-Pixel Android 15+ — any clean way to backport?

Repo: https://github.com/JoJa84/Codefone

---

## Version B — r/Android (alternate, Android-hack framing)

**Title:** TIL Android 15's Linux Terminal is a real Debian VM with root-in-guest — and it runs Claude Code natively

**Body:**

Probably old news to some of you, but I haven't seen this written up anywhere, and when I realized what it meant I couldn't stop thinking about it.

**The undocumented-ish thing:** In Android 15+, Developer Options → "Linux development environment" turns on a full Debian VM, backed by the Android Virtualization Framework (AVF). Not Termux. Not a chroot. A real VM with glibc, apt, systemd, and root inside the guest. Google shipped this quietly — the Terminal app is Google-signed, `com.google.android.virtualization.terminal`.

**What you can actually do with it:**

- Install any ARM64 Linux binary via official installers (the ones that fail on Termux because Bionic isn't real glibc).
- Run sshd inside the VM, forward it via Terminal's port-forwarding UI, `adb forward` to your laptop → SSH into your phone from a real keyboard.
- Survive reboots and OTAs without losing state.

I used it to run **Claude Code** (Anthropic's CLI coding agent) natively on a refurb Pixel 8. The official installer just works inside the VM because it's a real Debian rootfs. Took about 15 minutes end-to-end. Voice in/out too (whisper.cpp + espeak-ng).

**The interesting part isn't Claude specifically, it's the pattern:** the phone has a USB-C port. Once you've got a root shell in a real Debian guest, the phone becomes a universal diagnostic/control surface. Plug in an Arduino, an OBD-II reader, a USB-serial cable, a router — the VM can drive any of it. A $100 phone + purpose-built VM image = specialty field device for any vertical.

Not Pixel-specific by the way — AVF is in AOSP; Samsung and other OEMs just haven't enabled the Linux Terminal app yet. Expecting that to change late 2026.

**Questions for anyone who's gone deeper:**

- USB-C peripheral passthrough into the AVF guest — how well does it work? OBD-II? Serial consoles? Flash programmers?
- Anyone tried this on a pre-Android-15 Pixel via custom AVF build?
- Security model between Android host and Debian guest — known cracks?

My writeup (with step-by-step flash instructions, decisions log, scripts): https://github.com/JoJa84/Codefone
