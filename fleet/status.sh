#!/usr/bin/env bash
set -euo pipefail

# Quick health summary for the four fleet devices.

printf 'host       : %s\n' "$(hostname)"
printf 'flake attr : %s\n' "$(hostname)"

if command -v tailscale >/dev/null 2>&1; then
  printf '\n== tailscale ==\n'
  tailscale status --peers=false 2>/dev/null | sed 's/^/  /' || printf '  tailscale unavailable\n'
fi

printf '\n== ssh ==\n'
if ssh -o BatchMode=yes -o ConnectTimeout=5 lenovo-user true 2>/dev/null; then
  printf '  lenovo-user : reachable\n'
else
  printf '  lenovo-user : UNREACHABLE\n'
fi

printf '\n== adb ==\n'
if command -v adb >/dev/null 2>&1; then
  adb devices -l | sed 's/^/  /'
else
  printf '  adb not installed on this host\n'
fi

printf '\n== local ==\n'
if git -C /etc/nixos rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  dirty="$(git -C /etc/nixos status --porcelain | wc -l)"
  printf '  /etc/nixos dirty files: %s\n' "$dirty"
  printf '  branch: %s\n' "$(git -C /etc/nixos symbolic-ref --quiet --short HEAD || printf 'detached')"
fi
