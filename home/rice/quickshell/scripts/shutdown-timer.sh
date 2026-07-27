set -euo pipefail

# AppImage-launched sessions can leak incompatible libraries into user services.
# Every executable below comes from the Nix wrapper's PATH.
unset LD_LIBRARY_PATH

action="${1:-status}"
target="${2:-}"
runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$UID}/auto-shutdown"
cancel_file="$runtime_dir/cancel"
custom_deadline_file="$runtime_dir/custom-deadline"
pending_file="$runtime_dir/pending"
pending_deadline_file="$runtime_dir/pending-deadline"
agent_wait_file="$runtime_dir/agent-waiting"
alarm_pending_file="$runtime_dir/alarm-pending"
alarm_deadline_file="$runtime_dir/alarm-deadline"
alarm_unit_file="$runtime_dir/alarm-unit"
alarm_ringing_file="$runtime_dir/alarm-ringing"
alarm_audio_pid_file="$runtime_dir/alarm-audio-pid"
mkdir -p "$runtime_dir"
rm -f "$runtime_dir/custom-target"

read_deadline() {
  local deadline_file="$1"
  if [[ -r "$deadline_file" ]]; then
    head -n1 "$deadline_file" | awk '/^[0-9]+$/ { print; exit }'
  fi
}

json_status() {
  local alarm_deadline alarm_pending alarm_remaining alarm_ringing deadline now pending remaining
  pending=""
  if [[ -r "$pending_file" ]]; then
    pending="$(head -n1 "$pending_file")"
  fi
  deadline="$(read_deadline "$pending_deadline_file")"
  now="$(date +%s)"
  remaining=0
  if [[ -n "$deadline" && "$deadline" -gt "$now" ]]; then
    remaining=$((deadline - now))
  else
    rm -f "$pending_file" "$pending_deadline_file"
    pending=""
  fi

  alarm_pending=""
  if [[ -r "$alarm_pending_file" ]]; then
    alarm_pending="$(head -n1 "$alarm_pending_file")"
  fi
  alarm_ringing=false
  if [[ -e "$alarm_ringing_file" ]]; then
    alarm_ringing=true
  fi
  alarm_deadline="$(read_deadline "$alarm_deadline_file")"
  alarm_remaining=0
  if [[ -n "$alarm_deadline" && "$alarm_deadline" -gt "$now" ]]; then
    alarm_remaining=$((alarm_deadline - now))
  elif [[ "$alarm_ringing" == true ]]; then
    alarm_pending=""
  else
    rm -f "$alarm_pending_file" "$alarm_deadline_file" "$alarm_unit_file" "$alarm_audio_pid_file"
    alarm_pending=""
  fi

  printf '{"custom":"","pending":"%s","deadline":%s,"remaining":%s,"alarmPending":"%s","alarmDeadline":%s,"alarmRemaining":%s,"alarmRinging":%s,"cancel":false}\n' \
    "$pending" "${deadline:-0}" "$remaining" \
    "$alarm_pending" "${alarm_deadline:-0}" "$alarm_remaining" "$alarm_ringing"
}

stop_alarm_unit() {
  local unit=""
  if [[ -r "$alarm_unit_file" ]]; then
    unit="$(head -n1 "$alarm_unit_file")"
  fi
  if [[ "$unit" =~ ^quickshell-alarm-[0-9]+$ ]]; then
    systemctl --user stop "$unit.timer" "$unit.service" >/dev/null 2>&1 || true
    systemctl --user reset-failed "$unit.timer" "$unit.service" >/dev/null 2>&1 || true
  fi
}

stop_alarm_audio() {
  local audio_pid=""
  if [[ -r "$alarm_audio_pid_file" ]]; then
    audio_pid="$(head -n1 "$alarm_audio_pid_file")"
  fi
  if [[ "$audio_pid" =~ ^[0-9]+$ ]]; then
    kill "$audio_pid" >/dev/null 2>&1 || true
  fi
}

play_alarm() {
  local audio_pid
  while [[ -e "$alarm_ringing_file" ]]; do
    pw-play --volume=0.9 "@alarmSound@" >/dev/null 2>&1 &
    audio_pid=$!
    printf '%s\n' "$audio_pid" > "$alarm_audio_pid_file"
    wait "$audio_pid" || true
    rm -f "$alarm_audio_pid_file"
    if [[ -e "$alarm_ringing_file" ]]; then
      sleep 1
    fi
  done
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
    notify-send --app-name="Auto shutdown" --icon=system-shutdown -u critical \
      "Auto shutdown" "System will power off in $target minutes."
    json_status
    ;;
  cancel-pending)
    touch "$cancel_file"
    rm -f "$custom_deadline_file" "$pending_file" "$pending_deadline_file" "$agent_wait_file"
    notify-send --app-name="Auto shutdown" --icon=system-shutdown -u normal \
      "Auto shutdown" "Shutdown cancelled."
    json_status
    ;;
  schedule-alarm-in)
    if ! [[ "$target" =~ ^[0-9]+$ ]] || (( target < 1 || target > 720 )); then
      echo "Invalid alarm delay minutes: $target" >&2
      exit 2
    fi
    stop_alarm_unit
    deadline=$(( $(date +%s) + target * 60 ))
    unit="quickshell-alarm-$deadline"
    printf 'in %s min\n' "$target" > "$alarm_pending_file"
    printf '%s\n' "$deadline" > "$alarm_deadline_file"
    printf '%s\n' "$unit" > "$alarm_unit_file"
    if ! systemd-run --user --quiet --collect \
      --unit="$unit" \
      --on-active="${target}m" \
      --timer-property=AccuracySec=1s \
      "$0" alarm-fire "$deadline"; then
      rm -f "$alarm_pending_file" "$alarm_deadline_file" "$alarm_unit_file"
      echo "Could not schedule alarm" >&2
      exit 1
    fi
    notify-send --app-name="Alarm" --icon=alarm-symbolic -u normal \
      "Alarm set" "The alarm will ring in $target minutes."
    json_status
    ;;
  cancel-alarm)
    was_ringing=false
    if [[ -e "$alarm_ringing_file" ]]; then
      was_ringing=true
    fi
    stop_alarm_unit
    stop_alarm_audio
    rm -f "$alarm_pending_file" "$alarm_deadline_file" "$alarm_unit_file" "$alarm_ringing_file" "$alarm_audio_pid_file"
    notify-send --app-name="Alarm" --icon=alarm-symbolic -u normal \
      "Alarm" "$([[ "$was_ringing" == true ]] && printf 'Alarm silenced.' || printf 'Alarm cancelled.')"
    json_status
    ;;
  acknowledge-alarm)
    stop_alarm_unit
    stop_alarm_audio
    rm -f "$alarm_pending_file" "$alarm_deadline_file" "$alarm_unit_file" "$alarm_ringing_file" "$alarm_audio_pid_file"
    json_status
    ;;
  alarm-fire)
    current_deadline="$(read_deadline "$alarm_deadline_file")"
    if [[ -n "$target" && "$current_deadline" == "$target" ]]; then
      rm -f "$alarm_pending_file" "$alarm_deadline_file"
      touch "$alarm_ringing_file"
      play_alarm &
      alarm_loop_pid=$!
      selected_action="$(
        notify-send --app-name="Alarm" --icon=alarm-symbolic -u critical -t 0 \
          --action=acknowledge="Silence alarm" \
          "Alarm" "The timer has finished. Confirm to silence it." || true
      )"
      if [[ "$selected_action" == "acknowledge" ]]; then
        stop_alarm_audio
        rm -f "$alarm_ringing_file"
      fi
      wait "$alarm_loop_pid" || true
      rm -f "$alarm_ringing_file" "$alarm_audio_pid_file" "$alarm_unit_file"
    fi
    ;;
  *)
    echo "Usage: quickshell-shutdown-timer [status|schedule-in MINUTES|cancel-pending|schedule-alarm-in MINUTES|cancel-alarm|acknowledge-alarm]" >&2
    exit 2
    ;;
esac
