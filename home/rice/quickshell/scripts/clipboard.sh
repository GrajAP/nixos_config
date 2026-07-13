set -euo pipefail

action="${1:-list}"
encoded="${2:-}"

decode_entry() {
  if [[ -z "$encoded" ]]; then
    echo "Missing clipboard entry" >&2
    exit 2
  fi
  printf '%s' "$encoded" | base64 -d
}

case "$action" in
  list)
    python3 - <<'PY'
import base64
import json
import subprocess
import sys

entries = []
result = subprocess.run(["cliphist", "list"], check=False, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
for index, raw in enumerate(result.stdout.splitlines()):
    if not raw:
        continue
    parts = raw.split("\t", 1)
    entry_id = parts[0].strip()
    preview = parts[1].strip() if len(parts) > 1 else raw.strip()
    compact = " ".join(preview.split())
    if len(compact) > 180:
        compact = compact[:177] + "..."
    entries.append({
        "id": entry_id,
        "line": base64.b64encode(raw.encode("utf-8", "replace")).decode("ascii"),
        "preview": compact or "(empty)",
    })
print(json.dumps(entries[:80], ensure_ascii=False))
PY
    ;;
  copy)
    decode_entry | cliphist decode | wl-copy
    notify-send -u low -t 1500 "Clipboard" "Copied from history."
    ;;
  delete)
    decode_entry | cliphist delete
    notify-send -u low -t 1500 "Clipboard" "Removed entry."
    ;;
  wipe)
    cliphist wipe
    notify-send -u normal -t 1800 "Clipboard" "History cleared."
    ;;
  *)
    echo "Usage: quickshell-clipboard [list|copy ENTRY|delete ENTRY|wipe]" >&2
    exit 2
    ;;
esac
