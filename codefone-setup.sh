#!/usr/bin/env bash
# codefone-setup.sh — one-shot post-Magisk provisioning for a Codefone.
#
# PREREQUISITES (manual, ~10 min):
#   1. Pixel 8+ flashed to stock Android 16 via flash.android.com (Wipe + Force
#      Flash, bootloader unlocked, Locked OFF).
#   2. Bootloader unlocked, USB debugging ON, OEM unlocking ON.
#   3. Magisk installed via init_boot patching on both A/B slots (see FLASH.md §A0).
#   4. Phone connected via USB, `adb devices` shows one device.
#
# WHAT THIS SCRIPT DOES (~5-10 min):
#   • Verifies Magisk root via `su`.
#   • Installs the vmbridge Magisk module (persistent VM↔Android adb on 5555).
#   • Blocks OTA auto-update.
#   • Pushes Aurora Store APK if not yet installed.
#   • Enables Linux Terminal, launches it, waits for Debian VM to come online.
#   • Inside the VM: installs Claude Code, writes CLAUDE.md, ~/bin helpers,
#     voice stack (whisper.cpp + espeak-ng), SSH server, registers VM's
#     generated adbkey with the vmbridge Magisk module.
#   • Grants Terminal app RECORD_AUDIO + CAMERA for voice/vision features.
#   • Verifies end-to-end: VM→Android root, Claude runs, voice works.
#
# Usage:
#   bash codefone-setup.sh [--skip-vm-setup]
#
# Idempotent. Safe to re-run. If a step fails, you can re-run without undoing.

set -euo pipefail
ADB="${ADB:-C:/platform-tools/adb.exe}"
SKIP_VM=0
for a in "$@"; do [ "$a" = "--skip-vm-setup" ] && SKIP_VM=1; done

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
say() { echo; echo "▶ $*"; }
die() { echo "✗ $*" >&2; exit 1; }

# ---------- 0. Preflight ----------
say "Preflight: adb, Magisk root, device identity"
"$ADB" devices | grep -qE '\bdevice$' || die "No adb device. Plug USB + accept debugging prompt."
MODEL=$("$ADB" shell getprop ro.product.model | tr -d '\r')
BUILD=$("$ADB" shell getprop ro.build.id | tr -d '\r')
echo "Device: $MODEL ($BUILD)"
case "$MODEL" in *Pixel\ 8*|*Pixel\ 9*) ;; *) echo "⚠  model '$MODEL' untested, continuing anyway" ;; esac
"$ADB" shell 'su -c id' 2>&1 | grep -q 'uid=0' || die "Magisk root not active. Finish Magisk install first."

# ---------- 1. Install vmbridge Magisk module ----------
say "Installing vmbridge Magisk module"
ZIP="$REPO_DIR/vmbridge-magisk/vmbridge-magisk-v1.0.0.zip"
if [ ! -f "$ZIP" ]; then
  python3 - <<PY
import zipfile, os
src = r'$REPO_DIR/vmbridge-magisk'
dst = r'$ZIP'
z = zipfile.ZipFile(dst, 'w', zipfile.ZIP_DEFLATED)
for root, dirs, files in os.walk(src):
    for f in files:
        if f.endswith('.zip'): continue
        full = os.path.join(root, f)
        rel = os.path.relpath(full, src).replace(os.sep, '/')
        z.write(full, rel)
z.close()
PY
fi
TMP_WIN=$(cygpath -w "$ZIP" 2>/dev/null || echo "$ZIP")
MSYS_NO_PATHCONV=1 "$ADB" push "$TMP_WIN" //data/local/tmp/vmbridge.zip >/dev/null
"$ADB" shell 'su -c "
  rm -rf /data/adb/modules/vmbridge
  mkdir -p /data/adb/modules/vmbridge
  unzip -o /data/local/tmp/vmbridge.zip -d /data/adb/modules/vmbridge >/dev/null
  chmod 755 /data/adb/modules/vmbridge/*.sh
"'

# ---------- 2. Run service.sh once so bridge is live immediately ----------
say "Activating bridge"
"$ADB" shell 'su -c "sh /data/adb/modules/vmbridge/service.sh"' 2>&1 | tail -3 || true
# Wait for adbd to come back
for i in 1 2 3 4 5 6 7 8 9 10; do
  "$ADB" devices 2>&1 | grep -q 'device$' && break
  sleep 2
done

# ---------- 3. Block OTAs ----------
say "Blocking OTA auto-update"
"$ADB" shell 'settings put global ota_disable_automatic_update 1; settings put global auto_update_apps 0'
"$ADB" shell 'su -c "pm disable-user --user 0 com.google.android.gms.policy_update 2>/dev/null; pm disable-user --user 0 com.google.mainline.telemetry 2>/dev/null"' >/dev/null 2>&1 || true

# ---------- 4. Install Aurora Store if missing ----------
if ! "$ADB" shell 'pm list packages' | grep -q com.aurora.store; then
  say "Installing Aurora Store"
  AURORA="$REPO_DIR/apks/aurora-store.apk"
  if [ -f "$AURORA" ]; then
    "$ADB" install -r "$AURORA"
  else
    echo "⚠  apks/aurora-store.apk missing; sideload later via ~/bin/android install"
  fi
fi

# ---------- 4b. Install keyboard (FUTO) + voice IME (WhisperIME) ----------
# Per D24: FUTO Keyboard is the system default IME for typing.
# Per D25: WhisperIME (org.woheller69.whisper) is installed as an auxiliary
# voice-only IME. User switches to it via the Android IME switcher to dictate
# in any text field, including the Terminal where Claude runs. TFLite model
# is pushed to the app's external data dir. Fully offline, no Google.
install_apk() {
  local label=$1 url=$2 cache=$3 pkg=$4
  if "$ADB" shell 'pm list packages' | grep -q "package:$pkg"; then
    echo "  $label already installed"
    return
  fi
  say "Installing $label"
  mkdir -p "$REPO_DIR/apks"
  if [ ! -s "$cache" ] && [ -n "$url" ]; then
    curl -fsSL -o "$cache" "$url" || true
  fi
  if [ ! -s "$cache" ]; then
    echo "  ERROR: $label APK missing at $cache and no upstream URL. Skipping."
    return 1
  fi
  local tmp="$HOME/tmp-$(basename "$cache")"
  mkdir -p "$(dirname "$tmp")"
  cp "$cache" "$tmp"
  MSYS_NO_PATHCONV=1 "$ADB" install -r "$(cygpath -w "$tmp" 2>/dev/null || echo "$tmp")"
}
install_apk "FUTO Keyboard"    \
  "https://keyboard.futo.org/keyboard.apk" \
  "$REPO_DIR/apks/futo-keyboard.apk" \
  "org.futo.inputmethod.latin"
install_apk "WhisperIME"       \
  "https://f-droid.org/repo/org.woheller69.whisper_36.apk" \
  "$REPO_DIR/apks/whisperime-3.6.apk" \
  "org.woheller69.whisper"

say "Pushing WhisperIME model files"
WHISPER_DIR="/sdcard/Android/data/org.woheller69.whisper/files"
"$ADB" shell "mkdir -p $WHISPER_DIR"
missing_models=()
for f in whisper-tiny.en.tflite filters_vocab_en.bin; do
  src="$REPO_DIR/models/$f"
  [ -s "$src" ] || missing_models+=("$f")
done
if [ ${#missing_models[@]} -gt 0 ]; then
  die "Missing voice model file(s): ${missing_models[*]} in $REPO_DIR/models/. See models/README.md for how to populate them. Refusing to ship a phone with broken voice."
fi
for f in whisper-tiny.en.tflite filters_vocab_en.bin; do
  MSYS_NO_PATHCONV=1 "$ADB" push "$(cygpath -w "$REPO_DIR/models/$f" 2>/dev/null || echo "$REPO_DIR/models/$f")" "//sdcard/Android/data/org.woheller69.whisper/files/$f" >/dev/null
done

say "Enabling FUTO Keyboard (primary) + WhisperIME (voice) + mic permissions"
"$ADB" shell 'pm grant org.futo.inputmethod.latin android.permission.RECORD_AUDIO' 2>/dev/null || true
"$ADB" shell 'pm grant org.woheller69.whisper    android.permission.RECORD_AUDIO' 2>/dev/null || true
"$ADB" shell 'ime enable org.futo.inputmethod.latin/.LatinIME' 2>/dev/null || true
"$ADB" shell 'ime enable org.woheller69.whisper/com.whispertflite.WhisperInputMethodService' 2>/dev/null || true
"$ADB" shell 'ime set    org.futo.inputmethod.latin/.LatinIME' 2>/dev/null || true
"$ADB" shell 'ime disable org.futo.voiceinput/.VoiceInputMethodService' 2>/dev/null || true
"$ADB" shell 'settings put secure voice_recognition_service org.woheller69.whisper/com.whispertflite.WhisperRecognitionService' 2>/dev/null || true

# ---------- 5. Grant Terminal app mic + camera ----------
say "Granting Terminal app RECORD_AUDIO + CAMERA"
"$ADB" shell 'pm grant com.android.virtualization.terminal android.permission.RECORD_AUDIO' 2>/dev/null || true
"$ADB" shell 'pm grant com.android.virtualization.terminal android.permission.CAMERA' 2>/dev/null || true

# ---------- 5b. Screen never sleeps ----------
# The Terminal app loses audio focus when the screen blacks out — kills long
# voice sessions. This is an agent appliance, not a phone someone looks at.
# (Found by on-device Claude, 2026-04-20.)
say "Disabling screen timeout + enabling stay-on-while-plugged-in"
"$ADB" shell 'settings put system screen_off_timeout 2147483647' 2>/dev/null || true
"$ADB" shell 'settings put global stay_on_while_plugged_in 15'    2>/dev/null || true

# ---------- 6. Launch Terminal / start VM ----------
say "Starting Debian VM (Terminal app)"
"$ADB" shell 'am force-stop com.android.virtualization.terminal'
sleep 2
"$ADB" shell 'svc power stayon true; input keyevent KEYCODE_WAKEUP'
"$ADB" shell 'am start -n com.android.virtualization.terminal/.MainActivity' >/dev/null

# ---------- 7. Wait for VM to get an IP on avf_tap_fixed ----------
say "Waiting for VM network to come up"
VM_IP=""
for i in $(seq 1 60); do
  NEIGH=$("$ADB" shell 'ip neigh 2>/dev/null | grep "dev avf_tap_fixed" | awk "{print \$1}" | head -1' | tr -d '\r')
  if [ -n "$NEIGH" ] && "$ADB" shell "ping -c 1 -W 1 $NEIGH" 2>/dev/null | grep -q "1 received"; then
    VM_IP="$NEIGH"
    break
  fi
  sleep 2
done
[ -n "$VM_IP" ] || die "VM network never came up. Terminal may be stuck on 'Preparing terminal' — force-stop and retry."
echo "VM at $VM_IP"

# ---------- 8. Spawn nc relay for SSH ----------
say "Setting up nc relay for SSH (port 2223)"
"$ADB" shell "pkill -9 nc 2>/dev/null; nohup nc -L -p 2223 nc $VM_IP 2222 >/data/local/tmp/relay.log 2>&1 &"
"$ADB" forward --remove tcp:2223 2>/dev/null || true
"$ADB" forward tcp:2223 tcp:2223 >/dev/null

# ---------- 9. VM-side setup over SSH ----------
if [ "$SKIP_VM" = "1" ]; then
  say "--skip-vm-setup: leaving VM alone"
else
  # Ensure we can SSH (VM might not have openssh-server yet; first-boot handled later)
  sleep 3
  SSH_OPTS=(-p 2223 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5)
  SCP_OPTS=(-P 2223 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
  if ! ssh "${SSH_OPTS[@]}" droid@127.0.0.1 'true' 2>/dev/null; then
    PUBKEY=$(cat ~/.ssh/id_ed25519.pub 2>/dev/null || cat ~/.ssh/id_rsa.pub 2>/dev/null || true)
    if [ -z "$PUBKEY" ]; then
      die "No PC-side SSH pubkey found at ~/.ssh/id_{ed25519,rsa}.pub. Generate one and re-run."
    fi
    echo "⚠  SSH not yet available — the VM is on its first boot. On the phone, open the Terminal app and run these two commands (copy/paste):"
    echo
    echo "    curl -fsSL https://claude.ai/install.sh | bash"
    echo "    curl -fsSL https://raw.githubusercontent.com/JoJa84/Codefone/main/setup-keys.sh | bash -s -- '$PUBKEY'"
    echo
    echo "Then re-run: bash codefone-setup.sh"
    exit 0
  fi

  say "Preparing VM directories"
  ssh "${SSH_OPTS[@]}" droid@127.0.0.1 'mkdir -p ~/.claude/hooks ~/bin'

  say "Copying VM-side assets (CLAUDE.md + say + hook)"
  scp "${SCP_OPTS[@]}" "$REPO_DIR/vm-CLAUDE.md"                       droid@127.0.0.1:/home/droid/.claude/CLAUDE.md
  scp "${SCP_OPTS[@]}" "$REPO_DIR/scripts/vm-files/say"               droid@127.0.0.1:/home/droid/bin/say
  scp "${SCP_OPTS[@]}" "$REPO_DIR/scripts/vm-files/speak-response.sh" droid@127.0.0.1:/home/droid/.claude/hooks/speak-response.sh
  ssh "${SSH_OPTS[@]}" droid@127.0.0.1 'chmod +x ~/bin/say ~/.claude/hooks/speak-response.sh'

  say "Running vm-provision.sh over SSH"
  ssh "${SSH_OPTS[@]}" droid@127.0.0.1 'bash -s' < "$REPO_DIR/scripts/vm-provision.sh"

  # Optional Tailscale enrollment — gated on $TS_AUTH_KEY being set by operator.
  # If not provided, the phone still ships with adb+nc relay as its primary transport.
  if [ -n "${TS_AUTH_KEY:-}" ]; then
    say "Enrolling VM in Tailscale (TS_AUTH_KEY provided)"
    # --ssh enables Tailscale SSH (tainlet-identity auth, no PAM password needed).
    # --accept-routes lets the VM reach other subnet routes advertised by the tainlet.
    ssh "${SSH_OPTS[@]}" droid@127.0.0.1 \
      "curl -fsSL https://tailscale.com/install.sh | sudo -E sh && \
       sudo tailscale up --auth-key=$TS_AUTH_KEY --ssh --accept-routes --hostname=codefone-pixel8 && \
       tailscale ip -4"
  else
    echo "  (skipping Tailscale — set TS_AUTH_KEY to enroll this device)"
  fi
fi

# ---------- 10. Register VM adbkey with the Magisk module ----------
say "Registering VM adbkey with vmbridge module"
VM_KEY=$(ssh -p 2223 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null droid@127.0.0.1 'cat ~/.android/adbkey.pub' 2>/dev/null || true)
if [ -n "$VM_KEY" ]; then
  # Stash into /sdcard/Codefone/ so vmbridge service.sh picks it up on every boot
  "$ADB" shell "su -c 'mkdir -p /sdcard/Codefone'"
  "$ADB" shell "cat > /sdcard/Codefone/vm_adbkey.pub" <<< "$VM_KEY"
  "$ADB" shell "su -c 'sh /data/adb/modules/vmbridge/service.sh' >/dev/null 2>&1" || true
fi

# ---------- 11. Verify end-to-end ----------
say "Verification"
sleep 3
# Respawn relay (adbd may have restarted)
"$ADB" shell "pkill -9 nc 2>/dev/null; nohup nc -L -p 2223 nc $VM_IP 2222 >/data/local/tmp/relay.log 2>&1 &"
"$ADB" forward tcp:2223 tcp:2223 >/dev/null
sleep 2
OUT=$(ssh -p 2223 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null droid@127.0.0.1 '
  claude --version 2>&1 | head -1
  ~/bin/android su "id" 2>&1 | head -1
  command -v paplay >/dev/null && echo paplay_ok
  test -x ~/bin/say && echo say_ok
  test -x ~/.claude/hooks/speak-response.sh && echo hook_ok
  test -x ~/piper/bin/piper && ls ~/piper/voices/*.onnx 2>/dev/null | head -1 | grep -q onnx && echo piper_ok
' 2>&1 || true)
echo "$OUT"
echo "$OUT" | grep -q 'Claude Code' && echo "✓ Claude installed"       || { echo "✗ Claude missing"; FAIL=1; }
echo "$OUT" | grep -q 'uid=0'       && echo "✓ Android root via bridge"|| { echo "✗ bridge broken"; FAIL=1; }
echo "$OUT" | grep -q paplay_ok     && echo "✓ paplay present"         || { echo "✗ paplay missing (TTS will be silent)"; FAIL=1; }
echo "$OUT" | grep -q say_ok        && echo "✓ ~/bin/say installed"    || { echo "✗ ~/bin/say missing"; FAIL=1; }
echo "$OUT" | grep -q hook_ok       && echo "✓ Stop hook installed"    || { echo "✗ Stop hook missing"; FAIL=1; }
echo "$OUT" | grep -q piper_ok      && echo "✓ Piper + voice model"    || { echo "✗ Piper or voice model missing"; FAIL=1; }

# IME postcondition — D25 invariant: FUTO primary + WhisperIME enabled secondary.
DEFAULT_IME=$("$ADB" shell 'settings get secure default_input_method' | tr -d '\r')
ENABLED_IMES=$("$ADB" shell 'settings get secure enabled_input_methods' | tr -d '\r')
case "$DEFAULT_IME" in
  *org.futo.inputmethod.latin*) echo "✓ FUTO Keyboard is default IME" ;;
  *) echo "✗ default IME is '$DEFAULT_IME' (expected FUTO); typing will use wrong keyboard"; FAIL=1 ;;
esac
case "$ENABLED_IMES" in
  *org.woheller69.whisper*) echo "✓ WhisperIME enabled (voice)" ;;
  *) echo "✗ WhisperIME is not in enabled_input_methods; dictation unavailable"; FAIL=1 ;;
esac

if [ "${FAIL:-0}" = "1" ]; then
  echo
  echo "Setup completed with verification failures above. Device is NOT ready to ship."
  exit 2
fi

say "DONE. Summary:"
cat <<EOF
  Device: $MODEL ($BUILD)
  VM IP : $VM_IP
  SSH   : ssh -p 2223 droid@127.0.0.1
  Root  : ~/bin/android su 'CMD'
  Claude: ssh ... 'claude'
  Voice : ssh ... '~/bin/v' (hold-to-talk), '~/bin/say "text"' (tts)
EOF
