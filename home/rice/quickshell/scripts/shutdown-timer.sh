set -euo pipefail

action="${1:-status}"
target="${2:-}"
runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$UID}/auto-shutdown"
cancel_file="$runtime_dir/cancel"
custom_deadline_file="$runtime_dir/custom-deadline"
pending_file="$runtime_dir/pending"
pending_deadline_file="$runtime_dir/pending-deadline"
agent_wait_file="$runtime_dir/agent-waiting"
mkdir -p "$runtime_dir"
rm -f "$runtime_dir/custom-target"

read_deadline() {
  if [[ -r "$pending_deadline_file" ]]; then
    head -n1 "$pending_deadline_file" | awk '/^[0-9]+$/ { print; exit }'
  fi
}

json_status() {
  local deadline now remaining pending
  pending=""
  if [[ -r "$pending_file" ]]; then
    pending="$(head -n1 "$pending_file")"
  fi
  deadline="$(read_deadline)"
  now="$(date +%s)"
  remaining=0
  if [[ -n "$deadline" && "$deadline" -gt "$now" ]]; then
    remaining=$((deadline - now))
  else
    rm -f "$pending_file" "$pending_deadline_file"
    pending=""
  fi
  printf '{"custom":"","pending":"%s","deadline":%s,"remaining":%s,"cancel":false}\n' \
    "$pending" "${deadline:-0}" "$remaining"
}

case "$action" in
  status)
    json_status
    ;;
  schedule-in)
    if ! [[ "$target" =~ ^[0-9]+$ ]] || (( target < 1 || target > 720 )); then
      echo "Invalid shutdown delay minutes: $target" >&2
      exit 2
    fi
    deadline=$(( $(date +%s) + target * 60 ))
    printf '%s\n' "$deadline" > "$custom_deadline_file"
    printf 'in %s min\n' "$target" > "$pending_file"
    printf '%s\n' "$deadline" > "$pending_deadline_file"
    rm -f "$cancel_file" "$agent_wait_file"
    notify-send -u critical "Auto shutdown" "System will power off in $target minutes."
    json_status
    ;;
  cancel-pending)
    touch "$cancel_file"
    rm -f "$custom_deadline_file" "$pending_file" "$pending_deadline_file" "$agent_wait_file"
    notify-send -u normal "Auto shutdown" "Shutdown cancelled."
    json_status
    ;;
  *)
    echo "Usage: quickshell-shutdown-timer [status|schedule-in MINUTES|cancel-pending]" >&2
    exit 2
    ;;
esac
