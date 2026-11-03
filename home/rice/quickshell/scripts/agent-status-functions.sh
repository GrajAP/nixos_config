t3_agent_working() {
  local state_db="$HOME/.t3/userdata/statev2.sqlite"
  local running
  [[ -d "$HOME/.t3/userdata" ]] || return 1

  # A hung provider leaves its run "running" for hours, so a run only counts
  # while its thread moved in the last hour. A failed query counts as working:
  # if T3 moves its database again, staying on beats killing a running agent.
  running="$(sqlite3 -readonly -cmd '.timeout 1000' "$state_db" \
    "SELECT count(*) FROM orchestration_v2_projection_runs r
     JOIN orchestration_v2_projection_threads t USING (thread_id)
     WHERE r.status = 'running'
       AND t.updated_at > strftime('%Y-%m-%dT%H:%M:%fZ', 'now', '-60 minutes');" \
    2>/dev/null)" || return 0
  [[ "$running" != "0" ]]
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
