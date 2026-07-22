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
import os
from pathlib import Path
import re
import subprocess

entries = []
active_image_ids = set()
runtime_dir = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
preview_dir = runtime_dir / "quickshell-clipboard-previews"
image_pattern = re.compile(
    r"^\[\[ binary data .*? (png|jpe?g|webp|gif|bmp) (\d+)x(\d+) \]\]$",
    re.IGNORECASE,
)
result = subprocess.run(["cliphist", "list"], check=False, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
for raw in result.stdout.splitlines()[:80]:
    if not raw:
        continue
    parts = raw.split("\t", 1)
    entry_id = parts[0].strip()
    preview = parts[1].strip() if len(parts) > 1 else raw.strip()
    compact = " ".join(preview.split())
    if len(compact) > 180:
        compact = compact[:177] + "..."
    entry = {
        "id": entry_id,
        "line": base64.b64encode(raw.encode("utf-8", "replace")).decode("ascii"),
        "preview": compact or "(empty)",
        "kind": "text",
        "imagePath": "",
        "imageWidth": 0,
        "imageHeight": 0,
    }

    image_match = image_pattern.match(preview)
    if image_match and entry_id.isdigit():
        image_format, image_width, image_height = image_match.groups()
        try:
            preview_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
            image_path = preview_dir / f"{entry_id}.img"
            if not image_path.exists():
                decoded = subprocess.run(
                    ["cliphist", "decode"],
                    input=(raw + "\n").encode(),
                    check=False,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.DEVNULL,
                )
                if decoded.returncode != 0:
                    raise RuntimeError("cliphist decode failed")
                temporary_path = preview_dir / f".{entry_id}.tmp"
                temporary_path.write_bytes(decoded.stdout)
                temporary_path.replace(image_path)
            active_image_ids.add(entry_id)
            entry.update({
                "kind": "image",
                "preview": f"Image · {image_format.upper()} · {image_width} × {image_height}",
                "imagePath": str(image_path),
                "imageWidth": int(image_width),
                "imageHeight": int(image_height),
            })
        except (OSError, RuntimeError):
            pass

    entries.append(entry)

if preview_dir.exists():
    for image_path in preview_dir.glob("*.img"):
        if image_path.stem not in active_image_ids:
            try:
                image_path.unlink()
            except OSError:
                pass

print(json.dumps(entries, ensure_ascii=False))
PY
    ;;
  copy)
    decode_entry | cliphist decode | wl-copy
    notify-send -u low -t 1500 "Clipboard" "Copied from history."
    ;;
  delete)
    entry="$(decode_entry)"
    entry_id="${entry%%$'\t'*}"
    printf '%s' "$entry" | cliphist delete
    if [[ "$entry_id" =~ ^[0-9]+$ ]]; then
      rm -f "${XDG_RUNTIME_DIR:-/run/user/$UID}/quickshell-clipboard-previews/$entry_id.img"
    fi
    notify-send -u low -t 1500 "Clipboard" "Removed entry."
    ;;
  wipe)
    cliphist wipe
    rm -rf "${XDG_RUNTIME_DIR:-/run/user/$UID}/quickshell-clipboard-previews"
    notify-send -u normal -t 1800 "Clipboard" "History cleared."
    ;;
  *)
    echo "Usage: quickshell-clipboard [list|copy ENTRY|delete ENTRY|wipe]" >&2
    exit 2
    ;;
esac
