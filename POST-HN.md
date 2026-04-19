# Hacker News "Show HN" draft

**Title:** Show HN: Codefone – Claude Code running natively on a $100 refurb Pixel 8

**URL field:** https://github.com/JoJa84/Codefone

**Body:**

---

I'm a hobbyist (not a developer). I noticed something most people haven't yet.

Android 15+ ships a Linux Terminal app, hidden in Developer Options. It's a real Debian VM with glibc, apt, systemd, and root-in-guest, backed by the Android Virtualization Framework (AVF). Google shipped it quietly. Almost nobody's written about what it unlocks.

What it unlocks, on a $100 refurb Pixel 8:

- `curl -fsSL https://claude.ai/install.sh | bash` installs Claude Code 2.1.x as a native Linux binary inside the VM. No Termux workarounds — Termux's Bionic libc can't load Claude's musl binary. I spent a day on that before pivoting to the Linux Terminal VM, which just worked.
- SSH from your PC works out of the box. Linux Terminal exposes the VM's sshd through Android's port-forwarding UI; `adb forward` or WiFi bridges it to a laptop. Full keyboard, full Claude Code, in your pocket.
- No root. No custom ROM. Bootloader stays locked. Factory reset = clean slate in 5 minutes.
- Voice I/O works (whisper.cpp + espeak-ng + a Stop hook). I can talk to Claude Code while walking the dog.

The interesting part isn't the phone. It's the USB-C port.

Once you've got a root shell in a real Debian guest in your pocket, the phone stops being a phone. Plug in an Arduino → Claude flashes firmware. Plug in an OBD-II reader → Claude reads engine codes. Plug in a USB-serial cable → Claude talks to industrial gear. A $100 Pixel running a purpose-built VM image becomes a specialty field device for any vertical — auto mechanics, network admins, HVAC techs, bench-instrument controllers. The VM is the product; the phone is just the shell.

Honest positioning: Sealos DevBox, AgentOS, and Anthropic's own Remote Control (shipped Feb 2026) all solve "AI coding from anywhere" via cloud or tethered laptop. Codefone is the standalone on-device variant. Nobody else seems to be shipping this particular shape yet.

Status is v0.2, reference unit running on my desk. Not a product — source-available under PolyForm Noncommercial 1.0.0 (free for personal/non-commercial use; commercial license separate). I'd love help with the parts I know are weakest:

- USB-C peripheral passthrough into the AVF guest — how deep can we go?
- Vertical VM images — what does "Codefone for HVAC techs" actually contain?
- Security model — where are the cracks between Android host and Debian guest?
- Older Pixels / non-Pixel Android 15+ devices — any clean way to backport this?

Repo: https://github.com/JoJa84/Codefone
