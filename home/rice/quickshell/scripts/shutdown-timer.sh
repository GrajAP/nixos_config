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
break_pending_file="$runtime_dir/break-pending"
break_deadline_file="$runtime_dir/break-deadline"
break_unit_file="$runtime_dir/break-unit"
break_phase_file="$runtime_dir/break-phase"
break_work_file="$runtime_dir/break-work-min"
break_duration_file="$runtime_dir/break-duration-min"
break_repeat_file="$runtime_dir/break-repeat"
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
  local break_deadline break_duration_min break_pending break_phase break_remaining break_repeat break_work_min
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

  break_pending=""
  if [[ -r "$break_pending_file" ]]; then
    break_pending="$(head -n1 "$break_pending_file")"
  fi
  break_phase=""
  if [[ -r "$break_phase_file" ]]; then
    break_phase="$(head -n1 "$break_phase_file")"
  fi
  break_work_min=30
  if [[ -r "$break_work_file" ]]; then
    break_work_min="$(head -n1 "$break_work_file")"
  fi
  break_duration_min=5
  if [[ -r "$break_duration_file" ]]; then
    break_duration_min="$(head -n1 "$break_duration_file")"
  fi
  break_repeat=0
  if [[ -r "$break_repeat_file" ]]; then
    break_repeat="$(head -n1 "$break_repeat_file")"
  fi
  break_deadline="$(read_deadline "$break_deadline_file")"
  break_remaining=0
  if [[ -n "$break_deadline" && "$break_deadline" -gt "$now" ]]; then
    break_remaining=$((break_deadline - now))
  elif [[ "$break_phase" == "finished" ]]; then
    break_pending=""
    break_remaining=0
  elif [[ -n "$break_deadline" ]]; then
    rm -f "$break_pending_file" "$break_deadline_file" "$break_unit_file" "$break_phase_file"
    break_pending=""
    break_phase=""
  fi

  printf '{"custom":"","pending":"%s","deadline":%s,"remaining":%s,"alarmPending":"%s","alarmDeadline":%s,"alarmRemaining":%s,"alarmRinging":%s,"breakPending":"%s","breakDeadline":%s,"breakRemaining":%s,"breakPhase":"%s","breakWorkMin":%s,"breakDurationMin":%s,"breakRepeat":%s,"cancel":false}\n' \
    "$pending" "${deadline:-0}" "$remaining" \
    "$alarm_pending" "${alarm_deadline:-0}" "$alarm_remaining" "$alarm_ringing" \
    "$break_pending" "${break_deadline:-0}" "$break_remaining" "$break_phase" "${break_work_min:-30}" "${break_duration_min:-5}" "${break_repeat:-0}"
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

stop_break_unit() {
  local unit=""
  if [[ -r "$break_unit_file" ]]; then
    unit="$(head -n1 "$break_unit_file")"
  fi
  if [[ "$unit" =~ ^quickshell-break-[0-9]+$ ]]; then
    systemctl --user stop "$unit.timer" "$unit.service" >/dev/null 2>&1 || true
    systemctl --user reset-failed "$unit.timer" "$unit.service" >/dev/null 2>&1 || true
  fi
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
  schedule-break-in)
    work_target="${2:-30}"
    break_target="${3:-5}"
    repeat_flag="${4:-0}"
    if ! [[ "$work_target" =~ ^[0-9]+$ ]] || (( work_target < 1 || work_target > 720 )); then
      echo "Invalid break work delay minutes: $work_target" >&2
      exit 2
    fi
    if ! [[ "$break_target" =~ ^[0-9]+$ ]] || (( break_target < 1 || break_target > 120 )); then
      echo "Invalid break duration minutes: $break_target" >&2
      exit 2
    fi
    stop_break_unit
    deadline=$(( $(date +%s) + work_target * 60 ))
    unit="quickshell-break-$deadline"
    printf 'in %s min\n' "$work_target" > "$break_pending_file"
    printf '%s\n' "$deadline" > "$break_deadline_file"
    printf '%s\n' "$unit" > "$break_unit_file"
    printf 'work\n' > "$break_phase_file"
    printf '%s\n' "$work_target" > "$break_work_file"
    printf '%s\n' "$break_target" > "$break_duration_file"
    printf '%s\n' "$repeat_flag" > "$break_repeat_file"
    if ! systemd-run --user --quiet --collect \
      --unit="$unit" \
      --on-active="${work_target}m" \
      --timer-property=AccuracySec=1s \
      "$0" break-fire "$deadline" "work"; then
      rm -f "$break_pending_file" "$break_deadline_file" "$break_unit_file" "$break_phase_file"
      echo "Could not schedule break timer" >&2
      exit 1
    fi
    notify-send --app-name="Break Timer" --icon=preferences-system-time -u normal \
      "Break timer started" "Work session: $work_target minutes. Break reminder in $work_target minutes."
    json_status
    ;;
  cancel-break)
    was_active=false
    if [[ -e "$break_phase_file" ]]; then
      was_active=true
    fi
    stop_break_unit
    rm -f "$break_pending_file" "$break_deadline_file" "$break_unit_file" "$break_phase_file" "$break_work_file" "$break_duration_file" "$break_repeat_file"
    if [[ "$was_active" == true ]]; then
      notify-send --app-name="Break Timer" --icon=preferences-system-time -u normal \
        "Break Timer" "Break timer cancelled."
    fi
    json_status
    ;;
  acknowledge-break)
    stop_break_unit
    rm -f "$break_pending_file" "$break_deadline_file" "$break_unit_file" "$break_phase_file" "$break_work_file" "$break_duration_file" "$break_repeat_file"
    json_status
    ;;
  break-fire)
    current_deadline="$(read_deadline "$break_deadline_file")"
    fire_phase="${3:-work}"
    if [[ -n "$target" && "$current_deadline" == "$target" ]]; then
      break_work_min=30
      if [[ -r "$break_work_file" ]]; then
        break_work_min="$(head -n1 "$break_work_file")"
      fi
      break_duration_min=5
      if [[ -r "$break_duration_file" ]]; then
        break_duration_min="$(head -n1 "$break_duration_file")"
      fi
      break_repeat=0
      if [[ -r "$break_repeat_file" ]]; then
        break_repeat="$(head -n1 "$break_repeat_file")"
      fi

      if [[ "$fire_phase" == "work" ]]; then
        pw-play --volume=0.85 "@breakSound@" >/dev/null 2>&1 &
        notify-send --app-name="Break Timer" --icon=preferences-system-time -u critical \
          "Time for a break!" "You've worked for $break_work_min minutes. Take a $break_duration_min-minute break!"

        break_deadline=$(( $(date +%s) + break_duration_min * 60 ))
        unit="quickshell-break-$break_deadline"
        printf 'break (%s min)\n' "$break_duration_min" > "$break_pending_file"
        printf '%s\n' "$break_deadline" > "$break_deadline_file"
        printf '%s\n' "$unit" > "$break_unit_file"
        printf 'break\n' > "$break_phase_file"

        if ! systemd-run --user --quiet --collect \
          --unit="$unit" \
          --on-active="${break_duration_min}m" \
          --timer-property=AccuracySec=1s \
          "$0" break-fire "$break_deadline" "break"; then
          rm -f "$break_pending_file" "$break_deadline_file" "$break_unit_file" "$break_phase_file"
          echo "Could not schedule break phase timer" >&2
          exit 1
        fi
      elif [[ "$fire_phase" == "break" ]]; then
        pw-play --volume=0.85 "@breakSound@" >/dev/null 2>&1 &
        if [[ "$break_repeat" == "1" ]]; then
          deadline=$(( $(date +%s) + break_work_min * 60 ))
          unit="quickshell-break-$deadline"
          printf 'in %s min\n' "$break_work_min" > "$break_pending_file"
          printf '%s\n' "$deadline" > "$break_deadline_file"
          printf '%s\n' "$unit" > "$break_unit_file"
          printf 'work\n' > "$break_phase_file"

          notify-send --app-name="Break Timer" --icon=preferences-system-time -u normal \
            "Break finished!" "Break is over. Next $break_work_min-minute work session started."

          if ! systemd-run --user --quiet --collect \
            --unit="$unit" \
            --on-active="${break_work_min}m" \
            --timer-property=AccuracySec=1s \
            "$0" break-fire "$deadline" "work"; then
            rm -f "$break_pending_file" "$break_deadline_file" "$break_unit_file" "$break_phase_file"
            exit 1
          fi
        else
          printf 'finished\n' > "$break_phase_file"
          rm -f "$break_pending_file" "$break_deadline_file" "$break_unit_file"
          notify-send --app-name="Break Timer" --icon=preferences-system-time -u normal \
            "Break finished!" "Your $break_duration_min-minute break is over. Ready to start working again?"
        fi
      fi
    fi
    ;;
  *)
    echo "Usage: quickshell-shutdown-timer [status|schedule-in MINUTES|cancel-pending|schedule-alarm-in MINUTES|cancel-alarm|acknowledge-alarm|schedule-break-in WORK_MIN BREAK_MIN [REPEAT]|cancel-break|acknowledge-break]" >&2
    exit 2
    ;;
esac
