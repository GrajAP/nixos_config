#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

export SPARK_CORRECTOR_STATE_DIR="$test_dir/state"
# shellcheck disable=SC1091
source "$script_dir/spark-corrector"

clipboard_file="$test_dir/clipboard"
dialog_status=2

capture_active_window() {
  printf '%s' "test-window"
}

wl-paste() {
  printf '%s' "original clipboard"
}

capture_selection() {
  printf '%s' "tekst z błędem"
}

acquire_lock() {
  return 0
}

release_lock() {
  return 0
}

run_correction() {
  work_dir="$test_dir/work"
  response_file="$work_dir/response.json"
  corrected_file="$work_dir/corrected.txt"
  mkdir -p "$work_dir"
  printf '%s' '{"language":"pl","corrected_text":"tekst bez błędu","changes":[]}' \
    >"$response_file"
  printf '%s' "tekst bez błędu" >"$corrected_file"
}

yad() {
  return "$dialog_status"
}

wl-copy() {
  cat >"$clipboard_file"
}

notify_status() {
  return 0
}

correct_selection

if [[ "$(cat "$clipboard_file")" != "tekst bez błędu" ]]; then
  printf '%s\n' "Copy did not place the corrected text in the clipboard." >&2
  exit 1
fi

dialog_status=1
correct_selection

if [[ "$(cat "$clipboard_file")" != "original clipboard" ]]; then
  printf '%s\n' "Cancel did not restore the original clipboard." >&2
  exit 1
fi
