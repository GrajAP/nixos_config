#!/usr/bin/env bash
set -euo pipefail

sessions_root="$HOME/.codex/sessions"
if [[ ! -d "$sessions_root" ]]; then
  echo '{"ok":false,"error":"No Codex session directory found"}'
  exit 0
fi

if ! find "$sessions_root" -type f -name "*.jsonl" -print -quit | grep -q .; then
  echo '{"ok":false,"error":"No Codex session files found"}'
  exit 0
fi

general_entry=""
spark_entry=""
while IFS= read -r session_file; do
  [[ -z "$session_file" ]] && continue
  while IFS= read -r latest_line; do
    [[ -z "$latest_line" ]] && continue

    if parsed="$(printf '%s\n' "$latest_line" | jq -e -c '
      .payload.rate_limits as $limits
      | select(($limits | type) == "object")
      | {
          limitId: ($limits.limit_id // null),
          limitName: ($limits.limit_name // null),
          primaryUsedPercent: (
            if ($limits.primary.used_percent | type) == "number" then $limits.primary.used_percent
            elif ($limits.primary.available_percent | type) == "number" then (100 - $limits.primary.available_percent)
            else null
            end
          ),
          primaryAvailablePercent: (
            if ($limits.primary.available_percent | type) == "number" then $limits.primary.available_percent
            elif ($limits.primary.used_percent | type) == "number" then (100 - $limits.primary.used_percent)
            else null
            end
          ),
          primaryWindowMinutes: ($limits.primary.window_minutes // null),
          primaryResetsAt: ($limits.primary.resets_at // null),
          secondaryUsedPercent: (
            if ($limits.secondary.used_percent | type) == "number" then $limits.secondary.used_percent
            elif ($limits.secondary.available_percent | type) == "number" then (100 - $limits.secondary.available_percent)
            else null
            end
          ),
          secondaryAvailablePercent: (
            if ($limits.secondary.available_percent | type) == "number" then $limits.secondary.available_percent
            elif ($limits.secondary.used_percent | type) == "number" then (100 - $limits.secondary.used_percent)
            else null
            end
          ),
          secondaryWindowMinutes: ($limits.secondary.window_minutes // null),
          secondaryResetsAt: ($limits.secondary.resets_at // null),
          planType: ($limits.plan_type // null)
        }' 2>/dev/null)"; then
      limit_id="$(printf '%s\n' "$parsed" | jq -r '.limitId // ""')"
      limit_name="$(printf '%s\n' "$parsed" | jq -r '.limitName // ""')"
      if [[ -z "$spark_entry" && ( "$limit_id" == "codex_bengalfox" || "$limit_name" == *"Spark"* ) ]]; then
        spark_entry="$parsed"
      elif [[ -z "$general_entry" && "$limit_id" == "codex" ]]; then
        general_entry="$parsed"
      fi
    fi

    if [[ -n "$general_entry" && -n "$spark_entry" ]]; then
      break 2
    fi
  done < <(tail -n 2000 "$session_file" | tac | rg -F '"rate_limits"' || true)
done < <(find "$sessions_root" -type f -name "*.jsonl" -printf '%T@ %p\n' | sort -nr | awk '{print $2}' | head -n 8)

if [[ -z "$general_entry" && -z "$spark_entry" ]]; then
  echo '{"ok":false,"error":"No session entry with rate limits"}'
  exit 0
fi

jq -n -c \
  --argjson general "${general_entry:-null}" \
  --argjson spark "${spark_entry:-null}" '
    def flatten($prefix; $item):
      if $item == null then {}
      else {
        ($prefix + "LimitId"): ($item.limitId // null),
        ($prefix + "LimitName"): ($item.limitName // null),
        ($prefix + "PrimaryUsedPercent"): ($item.primaryUsedPercent // null),
        ($prefix + "PrimaryAvailablePercent"): ($item.primaryAvailablePercent // null),
        ($prefix + "PrimaryWindowMinutes"): ($item.primaryWindowMinutes // null),
        ($prefix + "PrimaryResetsAt"): ($item.primaryResetsAt // null),
        ($prefix + "SecondaryUsedPercent"): ($item.secondaryUsedPercent // null),
        ($prefix + "SecondaryAvailablePercent"): ($item.secondaryAvailablePercent // null),
        ($prefix + "SecondaryWindowMinutes"): ($item.secondaryWindowMinutes // null),
        ($prefix + "SecondaryResetsAt"): ($item.secondaryResetsAt // null)
      }
      end;
    {
      ok: true,
      planType: (($general.planType // $spark.planType) // null),
      generatedAt: (now | floor)
    }
    + flatten("codex"; $general)
    + flatten("spark"; $spark)'
