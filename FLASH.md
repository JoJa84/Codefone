# FLASH.md — Cousin's step-by-step

**Goal:** turn a Pixel 8+ into a DevBox in 15–20 minutes.

**Two device paths**:

| Path | Device examples | Root? | Claude Code runtime |
| --- | --- | --- | --- |
| **A — Pixel 8+ on Android 15+** (primary) | Pixel 8, 8 Pro, 9, 9 Pro, Fold | ❌ | Android's native **Linux Terminal** (Debian VM) |
| **B — Legacy Termux** (carrier-locked Samsung, pre-Android 15 devices) | Galaxy S20 FE Verizon, etc. | ❌ | Termux |

Path A is the recommended, supported direction. Path B is retained only for SKUs that can't run the Linux Terminal and is known to have Claude Code compatibility issues on 2.1.x.

## Shared prerequisites

- **PC with ADB installed** (Android SDK platform-tools — `C:\platform-tools` on Windows, `/usr/local/bin` on macOS/Linux)
- **USB-C cable** (USB 3+ preferred — USB 2 works but slower)
- This repo cloned locally
- WiFi for initial provisioning
- Phone with battery ≥ 50%

---

## Path A — Pixel 8+ with Linux Terminal (primary)

### A1. Unlock bootloader (one-time per device, ~5 min)

1. Phone: **Settings → About phone** → tap **Build number** 7 times → Developer options enabled.
2. Phone: **Settings → System → Developer options** → **OEM unlocking** → ON.
3. Reboot to bootloader: `adb reboot bootloader` (phone must be connected with USB debugging on).
4. Unlock: `fastboot flashing unlock` → on-phone, volume keys to "Unlock the bootloader", power to confirm. **This wipes the device.**
5. Reboot: `fastboot reboot`. Re-do the initial Android setup wizard.

### A2. Flash stock Android via Flash Tool (~15 min)

1. **Kill any running ADB server first:** `adb kill-server` (Flash Tool uses WebUSB, which can't share the USB handle).
2. Install the **Google USB driver** on Windows (`R:\Downloads\Delete Later\google_usb_driver\usb_driver\` or [download](https://developer.android.com/studio/run/win-usb)).
3. Open **Chrome or Edge** → go to [flash.android.com](https://flash.android.com).
4. Click **Add new device** (or select your plugged-in phone from the list).
5. Select the latest stable build for your device (e.g., `shiba-user BP4A.251205.006` for Pixel 8 — Android 15+ is required for Linux Terminal).
6. **Toggle settings — exactly these:**
   - Wipe Device: ✅ **ON**
   - Lock Bootloader: ❌ **OFF** (needed so buyer can reflash later if desired)
   - Force Flash all Partitions: ✅ **ON**
   - Disable Verity: ❌ OFF (leave default)
   - Disable Verification: ❌ OFF (leave default)
   - Skip Secondary: ❌ OFF (flash both A/B slots)
7. Click **Install**. Approve browser's USB permission prompt. Phone auto-reboots to fastboot and flashing begins.
8. **Don't unplug or close the browser tab.** ~15 min on USB 2, ~5 min on USB 3+.
9. Phone reboots into Android 16 setup wizard.
10. **Skip Google sign-in.** No Play Store needed — Claude Code and everything else installs via the Linux Terminal. Skip Samsung account (N/A on Pixel), skip all optional prompts.

### A3. Enable Developer Options + Linux Terminal

On the fresh Android install:
1. Settings → About phone → tap **Build number** 7 times.
2. Settings → System → Developer options:
   - **USB debugging** ON
   - **OEM unlocking** ON (should already be)
   - **Linux development environment** → toggle **On**
3. Plug USB, approve "Allow USB debugging" on phone, check **"Always allow from this computer"**.

### A4. Open Linux Terminal and let Debian download

1. Open the **Terminal** app (appears in the app drawer once Linux dev is enabled).
2. It downloads a ~565 MB Debian rootfs (first time only, ~2 min on decent WiFi).
3. Wait for the `droid@debian:~$` prompt.

### A5. Install Claude Code inside the VM (~30 sec)

At the `droid@debian:~$` prompt:

```
curl -fsSL https://claude.ai/install.sh | bash
echo 'export PATH=$HOME/.local/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
claude --version
```

Expected output:
```
Installing Claude Code native build latest...
✔ Claude Code successfully installed!
Version: 2.1.113
```

### A6. Set up SSH (optional but recommended)

Inside the VM:

```
sudo apt update && sudo apt install -y openssh-server
echo "Port 2222" | sudo tee -a /etc/ssh/sshd_config
sudo systemctl enable --now ssh
mkdir -p ~/.ssh && chmod 700 ~/.ssh
echo '<paste your PC public key here>' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

In the Terminal app: gear icon → **Port forwarding** → add **2222**.

From your PC:
```bash
adb forward tcp:2222 tcp:2222
ssh -p 2222 droid@127.0.0.1
```

### A7. Sign in to Claude

Inside the VM (on phone or over SSH):
```
claude login
```

Follow the browser OAuth prompt. Done.

### A8. Final device hardening

1. Settings → Battery → **Adaptive battery** → ON.
2. Settings → Apps → Terminal → Battery → **Unrestricted**.
3. Settings → Display → Screen timeout → **10 minutes** (or longer) — prevents the "Preparing terminal" VM reboot nag.
4. Enable Screen Pinning: Settings → Security & privacy → More security & privacy → **App pinning** → On. Pin the Terminal app via the recents view.
5. **Forget your shop's WiFi** before shipping: Settings → Network → WiFi → long-press SSID → Forget.

---

## Path B — Legacy Termux (carrier-locked Samsungs, pre-Android 15)

⚠️ **Known issue:** Claude Code 2.1.x's pre-built binary fails to exec on Termux's Bionic libc. Use only if you must support a device that can't run the Linux Terminal. Pin to `@anthropic-ai/claude-code@2.0.x` or be prepared to run from source.

### B1. Factory reset the phone

Settings → General management → Reset → Factory data reset. Confirm. Phone boots into setup wizard.

### B2. Complete Android setup (skip Google)

1. Connect to **your shop's WiFi** (we'll forget it before shipping).
2. Skip Google account sign-in. Skip Samsung account. Skip everything optional.
3. Land on home screen.

### B3. Enable Developer Options + USB debugging + Install via USB

1. Settings → About phone → Software information → tap **Build number** 7 times.
2. Settings → Developer options:
   - **USB debugging** ON
   - **Install via USB** ON
3. Plug USB, accept "Allow USB debugging" → **Always allow from this computer**.

### B4. Strip Samsung / Verizon bloatware (~5 min)

Run `adb shell pm uninstall --user 0 <package>` per the curated list in `R:\Downloads\Delete Later\devbox-s20-apks\bloat-list.txt`. This disables bloat for user 0 without root — reversible by factory reset.

**Do NOT uninstall:** `com.android.*`, `com.google.android.gms`, `com.google.android.gsf`, `com.samsung.android.keyscafe` (keyboard), or anything starting with `com.sec.android.inputmethod`.

### B5. Install Termux + DevBox scripts

From repo root on PC:
```bash
bash flash-device.sh
```

### B6. Provision on device

On phone in Termux:
```
termux-setup-storage   # tap Allow
cp ~/storage/downloads/devbox/* ~/
bash ~/provision.sh
```

Pin Claude Code version in `provision.sh` if 2.1.x fails:
```bash
npm install -g @anthropic-ai/claude-code@2.0
```

Rest of Path B is unchanged from the pre-pivot docs — kiosk setup, forget WiFi, box up.

---

## Troubleshooting

**"adb: no devices/emulators found"**
Re-accept the USB debugging prompt on the phone. Try `adb kill-server && adb start-server`. On Pixel path, ensure Flash Tool tab is closed (it holds the USB handle).

**"Preparing terminal" spinner hangs forever (Path A)**
Known Android 15/16 bug — the AVF service wedges when the screen locks mid-session. Fix: long-press Terminal icon → App info → **Force stop**. Reopen. Takes 5 seconds.

**Claude Code installer fails: "command not found"**
Make sure you're inside the Debian VM (`droid@debian:~$`), not Android's shell. If the prompt shows `|android:/ $`, you're in the wrong place — tap the Terminal app, not adb shell.

**`claude: command not found` after install**
`.bashrc` PATH export didn't apply. Run:
```
echo 'export PATH=$HOME/.local/bin:$PATH' >> ~/.profile
source ~/.profile
```

**Flash Tool says "device appears to be in use by another program"**
Classic: ADB server is running on your PC. `adb kill-server` (and don't run any `adb` commands until Flash Tool finishes — even `adb devices` auto-restarts the server).

**`adb push /sdcard/Download/foo.img` fails with `secure_mkdirs() failed`**
Git Bash on Windows mangling the path. Prefix with `MSYS_NO_PATHCONV=1` or use double-slash: `//sdcard/Download/foo.img`.

**"My Pixel keeps rebooting into the wrong slot after an OTA"**
This is Android's standard A/B behavior — OTAs apply to the inactive slot, and reboot flips to it. Since we're on stock (no Magisk), this is harmless. If root was previously installed and you see it "vanish," that's why — no longer a problem on v0.2 since we dropped Magisk.

---

## What's not in v0.2

- Bundled APKs in-repo (we download latest at flash time).
- Automated bloatware-stripper for Path B (`strip-bloat-s20.sh` is a todo).
- Branded bootscreen / splash screen — stock Android boot.
- `devbox revive` one-tap VM recovery script.
- First-boot wizard inside the Debian VM (currently manual).

See `HANDOFF.md` for live status.
