set -euo pipefail

action="${1:-toggle}"
export PATH="/etc/profiles/per-user/$USER/bin:$HOME/.nix-profile/bin:$PATH"
if ! command -v whisper-record-v2 >/dev/null 2>&1; then
  notify-send "Voice to text" "whisper-record-v2 is not available in PATH"
  exit 127
fi

exec whisper-record-v2 "$action"
