#!/usr/bin/env bash
# Stop hook: read Claude's final assistant message from the transcript and speak it aloud.
# Skips code blocks, markdown fluff, and caps length so long outputs don't monopolize the speaker.
set -euo pipefail

# Hooks are spawned by Claude Code without the PulseAudio env that interactive
# shells inherit, so paplay silently fails. Re-export them here so the hook is
# self-sufficient regardless of parent environment.
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export PULSE_SERVER="${PULSE_SERVER:-unix:$XDG_RUNTIME_DIR/pulse/native}"

INPUT=$(cat)
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty')
[ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] || exit 0

# Pull the text content of the most recent assistant message that actually
# contains text (skip messages that are pure tool_use — those have no prose
# to speak). Walks the transcript in reverse.
LAST=$(tac "$TRANSCRIPT" | while IFS= read -r line; do
  role=$(printf '%s' "$line" | jq -r '.message.role // .type // empty' 2>/dev/null || true)
  [ "$role" = "assistant" ] || continue
  text=$(printf '%s' "$line" | jq -r '
    (.message.content // [])
    | map(select(.type == "text") | .text)
    | join("\n")
  ' 2>/dev/null)
  if [ -n "$text" ] && [ "$text" != "null" ]; then
    printf '%s' "$text"
    break
  fi
done) || true

[ -n "$LAST" ] || exit 0

# Clean for TTS: strip code fences, inline code, URLs, markdown formatting, cap length.
CLEAN=$(printf '%s' "$LAST" \
  | awk 'BEGIN{in_code=0} /^```/{in_code=!in_code; next} !in_code{print}' \
  | sed -E 's/`[^`]*`/ /g; s/\*\*([^*]+)\*\*/\1/g; s/\*([^*]+)\*/\1/g; s/_([^_]+)_/\1/g; s/#+ //g' \
  | sed -E 's#https?://[^[:space:])]+# link #g' \
  | sed -E 's/[—–]/ - /g' \
  | tr -s ' \n' ' ' \
  | cut -c 1-600)

[ -n "$CLEAN" ] || exit 0

# Speak in background so hook returns quickly. Prefer piper (neural TTS, natural voice);
# fall back to espeak-ng if piper is missing.
PIPER_BIN="$HOME/piper/bin/piper"
# Pick best available voice: high > libritts_r > medium
PIPER_VOICE=""
for v in en_US-libritts_r-medium en_US-lessac-high en_US-amy-medium; do
  if [ -f "$HOME/piper/voices/$v.onnx" ]; then
    PIPER_VOICE="$HOME/piper/voices/$v.onnx"; break
  fi
done
if [ -x "$PIPER_BIN" ] && [ -n "$PIPER_VOICE" ]; then
  (
    printf '%s' "$CLEAN" | LD_LIBRARY_PATH="$HOME/piper/bin" \
      "$PIPER_BIN" --model "$PIPER_VOICE" --output-raw 2>/dev/null \
      | paplay --raw --rate=22050 --format=s16le --channels=1 >/dev/null 2>&1
  ) &
else
  nohup espeak-ng -s 175 -v en-us+f3 "$CLEAN" >/dev/null 2>&1 &
fi
disown || true
exit 0
