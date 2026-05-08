#!/bin/bash
set -euo pipefail
cd /etc/nixos/

alejandra /etc/nixos/ &>/dev/null \
  || ( alejandra /etc/nixos/ ; echo "formatting failed!" && exit 1 )

git add -A

echo "NixOS Rebuilding..."

nix-channel --update
cmd=(nh os switch)
if [ "${1:-}" = "--update" ]; then
  cmd+=(--update)
  echo "Updating flake inputs before switching..."
else
  echo "Using existing flake.lock (no input update)."
fi
"${cmd[@]}"

nh clean all --keep 3

git commit -m "$(date '+%Y-%m-%d %H:%M')"

echo "Rebuild finished"
git push -u origin main
