#!/usr/bin/env bash
# codefone-revive.sh — unstick the AVF audio pipe and/or a wedged VM.
#
# Tries the cheapest fix first, escalates only if needed:
#   1. Restart PulseAudio inside the VM  (no downtime)
#   2. Force-stop + relaunch the Terminal app on Android  (VM reboots, ~30s)
#
# Invoke from PC:   bash scripts/codefone-revive.sh
# Invoke on-phone:  drop this as a home-screen shortcut that runs it via
#                   Tasker or the Terminal app; symptom = no TTS audio OR
#                   "Preparing terminal" hang.
set -euo pipefail

ADB="${ADB:-${CODEFONE_ADB:-adb}}"
SERIAL="${CODEFONE_SERIAL:-}"
[ -n "$SERIAL" ] && ADB="$ADB -s $SERIAL"

VM_SSH_HOST="${VM_SSH_HOST:-100.65.116.108}"
VM_SSH_PORT="${VM_SSH_PORT:-2222}"
VM_SSH_USER="${VM_SSH_USER:-droid}"

say() { echo "[revive] $*"; }

# ---- Step 1: try restarting Pulse inside the VM ----
if ssh -o ConnectTimeout=4 -o BatchMode=yes -p "$VM_SSH_PORT" \
       "$VM_SSH_USER@$VM_SSH_HOST" true 2>/dev/null; then
  say "VM reachable — restarting PulseAudio"
  ssh -p "$VM_SSH_PORT" "$VM_SSH_USER@$VM_SSH_HOST" \
    'systemctl --user restart pulseaudio.service 2>/dev/null || \
     (pulseaudio -k 2>/dev/null; pulseaudio --start 2>/dev/null); \
     sleep 1; \
     printf "audio test" | LD_LIBRARY_PATH=$HOME/piper/bin \
       $HOME/piper/bin/piper --model $HOME/piper/voices/en_US-amy-medium.onnx \
       --output-raw 2>/dev/null | \
       paplay --raw --rate=22050 --format=s16le --channels=1 && \
     echo OK' 2>/dev/null | tail -1 | grep -q OK && {
    say "Pulse restart succeeded. Audio should work now."
    exit 0
  }
  say "Pulse restart did not restore audio — escalating to Terminal restart."
else
  say "VM not reachable over SSH — going straight to Terminal restart."
fi

# ---- Step 2: force-stop + relaunch the Terminal app ----
say "Force-stopping com.android.virtualization.terminal"
$ADB shell 'am force-stop com.android.virtualization.terminal' || true
sleep 2

say "Relaunching Terminal (VM will auto-start via vmbridge)"
$ADB shell 'svc power stayon true; input keyevent KEYCODE_WAKEUP' || true
$ADB shell 'am start -n com.android.virtualization.terminal/.MainActivity' >/dev/null || {
  say "ERROR: failed to relaunch Terminal via adb. Open it manually on-device."
  exit 1
}

say "Waiting for VM to come back up (~30-60s)..."
for i in $(seq 1 20); do
  sleep 4
  if ssh -o ConnectTimeout=2 -o BatchMode=yes \
         -p "$VM_SSH_PORT" "$VM_SSH_USER@$VM_SSH_HOST" true 2>/dev/null; then
    say "VM back up after ~${i}0s"
    exit 0
  fi
done

say "VM did not come back within 80s. Check Terminal app manually."
exit 1
