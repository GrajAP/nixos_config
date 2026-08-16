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

while IFS= read -r session_file; do
  [[ -z "$session_file" ]] && continue
  rg -F '"rate_limits"' "$session_file" | tac || true
done < <(find "$sessions_root" -type f -name "*.jsonl" -printf '%T@ %p\n' | sort -nr | awk '{print $2}' | head -n 32) \
  | jq -s -c '
    def normalize:
      .payload.rate_limits
      | select(type == "object")
      | {
        limitId: (.limit_id // null),
        limitName: (.limit_name // null),
        primaryUsedPercent: (
          if (.primary.used_percent | type) == "number" then .primary.used_percent
          elif (.primary.available_percent | type) == "number" then (100 - .primary.available_percent)
          else null
          end
        ),
        primaryAvailablePercent: (
          if (.primary.available_percent | type) == "number" then .primary.available_percent
          elif (.primary.used_percent | type) == "number" then (100 - .primary.used_percent)
          else null
          end
        ),
        primaryWindowMinutes: (
          (.primary.window_duration_mins // .primary.window_minutes // null)
        ),
        primaryResetsAt: (.primary.resets_at // null),
        secondaryUsedPercent: (
          if (.secondary.used_percent | type) == "number" then .secondary.used_percent
          elif (.secondary.available_percent | type) == "number" then (100 - .secondary.available_percent)
          else null
          end
        ),
        secondaryAvailablePercent: (
          if (.secondary.available_percent | type) == "number" then .secondary.available_percent
          elif (.secondary.used_percent | type) == "number" then (100 - .secondary.used_percent)
          else null
          end
        ),
        secondaryWindowMinutes: (
          (.secondary.window_duration_mins // .secondary.window_minutes // null)
        ),
        secondaryResetsAt: (.secondary.resets_at // null),
        planType: (.plan_type // null)
      };
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
    [.[] | normalize] as $entries
    | ($entries | map(select(.limitId == "codex")) | .[0] // null) as $general
    | ($entries | map(select(.limitId == "codex_bengalfox" or ((.limitName // "") | contains("Spark")))) | .[0] // null) as $spark
    | if $general == null and $spark == null then
        {ok: false, error: "No session entry with rate limits"}
      else
        {
          ok: true,
          planType: (($general.planType // $spark.planType) // null),
          generatedAt: (now | floor)
        }
        + flatten("codex"; $general)
        + flatten("spark"; $spark)
      end'
