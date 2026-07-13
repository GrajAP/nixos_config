set -euo pipefail

mode="${1:-edit}"
target="${2:-}"
mkdir -p "$HOME/pics"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell-tools"
mkdir -p "$state_dir"
log_file="$state_dir/screenshot.log"
{
  echo "--- $(date --iso-8601=seconds) mode=$mode ---"
  echo "WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-}"
  echo "XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-}"
} >> "$log_file"

kill_stale_captures() {
  local stale=()
  local pid ppid args parent_args
  while read -r pid ppid args; do
    [[ -n "${pid:-}" ]] || continue
    [[ "$pid" == "$$" ]] && continue

    if [[ "$args" == *"quickshell-screenshot edit"* || "$args" == *"quickshell-screenshot copy"* || "$args" == *"quickshell-screenshot save"* ]]; then
      stale+=("$pid")
      continue
    fi

    if [[ "$args" == slurp* ]]; then
      parent_args="$(ps -o args= -p "$ppid" 2>/dev/null || true)"
      if [[ "$parent_args" == *"quickshell-screenshot"* ]]; then
        stale+=("$pid")
      fi
    fi
  done < <(ps -u "$(id -u)" -o pid= -o ppid= -o args=)

  if ((${#stale[@]} > 0)); then
    echo "killing stale screenshot process(es): ${stale[*]}" >> "$log_file"
    kill "${stale[@]}" 2>/dev/null || true
    sleep 0.1
    kill -KILL "${stale[@]}" 2>/dev/null || true
  fi
}

slurp_pid=""
slurp_output=""
cleanup_selector() {
  if [[ -n "$slurp_pid" ]]; then
    kill "$slurp_pid" 2>/dev/null || true
  fi
  if [[ -n "$slurp_output" ]]; then
    rm -f "$slurp_output"
  fi
}
trap cleanup_selector EXIT INT TERM

copy_file() {
  local file="$1"
  [[ -f "$file" ]] || { echo "missing file: $file" >> "$log_file"; exit 2; }
  wl-copy -t image/png < "$file" 2>> "$log_file"
  notify-send "Screenshot" "Copied to clipboard"
}

save_file() {
  local source="$1"
  [[ -f "$source" ]] || { echo "missing file: $source" >> "$log_file"; exit 2; }
  local file
  file="$HOME/pics/screenshot-$(date +'%F-%H%M%S').png"
  cp "$source" "$file"
  wl-copy -t image/png < "$file" 2>> "$log_file"
  notify-send "Screenshot" "Saved and copied: $(basename "$file")"
  printf '%s\n' "$file"
}

render_edited() {
  local source="$1"
  local strokes="${2:-[]}"
  local output="$state_dir/latest-screenshot-edited.png"
  [[ -f "$source" ]] || { echo "missing file: $source" >> "$log_file"; exit 2; }
  SOURCE="$source" STROKES="$strokes" OUTPUT="$output" python3 - <<'PY' 2>> "$log_file"
import json
import os
from PIL import Image, ImageDraw, ImageFont

source = os.environ["SOURCE"]
output = os.environ["OUTPUT"]
try:
    payload = json.loads(os.environ.get("STROKES", "[]"))
except json.JSONDecodeError:
    payload = []
if isinstance(payload, dict):
    annotations = payload.get("annotations", payload.get("strokes", []))
elif isinstance(payload, list):
    annotations = payload
else:
    annotations = []

image = Image.open(source).convert("RGBA")
draw = ImageDraw.Draw(image)
font_path = "${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSans-Bold.ttf"

for annotation in annotations:
    if not isinstance(annotation, dict):
        continue
    if annotation.get("type") == "text":
        text = str(annotation.get("text", "")).strip()
        if not text:
            continue
        x = float(annotation.get("x", 0))
        y = float(annotation.get("y", 0))
        color = annotation.get("color", "#ff4d6d")
        size = max(8, int(round(float(annotation.get("size", 32)))))
        try:
            font = ImageFont.truetype(font_path, size=size)
        except OSError:
            font = ImageFont.load_default()
        stroke_width = max(2, int(round(size / 9)))
        draw.text((x, y), text, fill=color, font=font, stroke_width=stroke_width, stroke_fill=(0, 0, 0, 184))
        continue

    points = annotation.get("points", [])
    if len(points) < 1:
        continue
    color = annotation.get("color", "#ff4d6d")
    width = max(1, int(round(float(annotation.get("width", 4)))))
    xy = [(float(point.get("x", 0)), float(point.get("y", 0))) for point in points]
    if len(xy) == 1:
        x, y = xy[0]
        radius = width / 2
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=color)
    else:
        draw.line(xy, fill=color, width=width, joint="curve")
        radius = width / 2
        for x, y in (xy[0], xy[-1]):
            draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=color)
image.save(output)
print(output)
PY
}

case "$mode" in
  copy-file)
    copy_file "$target"
    exit 0
    ;;
  save-file)
    save_file "$target"
    exit 0
    ;;
  copy-edited)
    edited="$(render_edited "$target" "${3:-[]}")"
    copy_file "$edited"
    printf '%s\n' "$edited"
    exit 0
    ;;
  save-edited)
    edited="$(render_edited "$target" "${3:-[]}")"
    save_file "$edited"
    exit 0
    ;;
esac

kill_stale_captures
sleep 0.15
slurp_output="$state_dir/slurp-$$.out"
: > "$slurp_output"
slurp -b 00000066 -c 7aa2f7ff -s 7aa2f733 > "$slurp_output" 2>> "$log_file" &
slurp_pid="$!"
set +e
wait "$slurp_pid"
status="$?"
set -e
slurp_pid=""
if [[ "$status" -ne 0 ]]; then
  echo "slurp failed: $status" >> "$log_file"
  exit "$status"
fi
geometry="$(< "$slurp_output")"
rm -f "$slurp_output"
slurp_output=""
[[ -n "$geometry" ]] || exit 130
echo "geometry=$geometry" >> "$log_file"
sleep 0.08

tmp="$state_dir/latest-screenshot.png"

case "$mode" in
  edit)
    grim -g "$geometry" "$tmp" 2>> "$log_file"
    printf '%s\n' "$tmp"
    ;;
  copy)
    grim -g "$geometry" "$tmp" 2>> "$log_file"
    copy_file "$tmp"
    ;;
  save)
    grim -g "$geometry" "$tmp" 2>> "$log_file"
    save_file "$tmp"
    ;;
  *)
    echo "Usage: quickshell-screenshot [edit|copy|save|copy-file|save-file|copy-edited|save-edited]" >&2
    exit 2
    ;;
esac
