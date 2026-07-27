t3_agent_working() {
  local state_db="$HOME/.t3/userdata/state.sqlite"
  [[ -r "$state_db" ]] || return 1

  [[ "$(sqlite3 -readonly -cmd '.timeout 1000' "$state_db" \
    "SELECT EXISTS(SELECT 1 FROM projection_thread_sessions WHERE status = 'running' AND active_turn_id IS NOT NULL);" \
    2>/dev/null || true)" == "1" ]]
}

codex_agent_working() {
  local process_dir fd session_file latest_event

  for process_dir in /proc/[0-9]*; do
    [[ -r "$process_dir/comm" ]] || continue
    [[ "$(<"$process_dir/comm")" == "codex" ]] || continue

    for fd in "$process_dir"/fd/*; do
      session_file="$(readlink -f "$fd" 2>/dev/null || true)"
      case "$session_file" in
        "$HOME/.codex/sessions/"*.jsonl) ;;
        *) continue ;;
      esac

      latest_event="$(
        tac "$session_file" 2>/dev/null \
          | rg -m 1 '"type":"(task_started|task_complete|turn_aborted)"' \
          | jq -r '.payload.type // empty' 2>/dev/null \
          || true
      )"
      [[ "$latest_event" == "task_started" ]] && return 0
    done
  done

  return 1
}

ai_agent_working() {
  t3_agent_working || codex_agent_working
}
