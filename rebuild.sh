#!/bin/bash
set -euo pipefail
cd /etc/nixos/
#git pull

git add -A

if [ -z "$(git diff --cached --name-only)" ]; then
  echo "No changes to commit"
  exit 0
fi

# Autoformat your nix files
alejandra /etc/nixos/ &>/dev/null \
  || ( alejandra /etc/nixos/ ; echo "formatting failed!" && exit 1 )

git add -A

echo "NixOS Rebuilding..."

cmd=(nh os switch)
if [ "${1:-}" = "--update" ]; then
  cmd+=(--update)
  echo "Updating flake inputs before switching..."
else
  echo "Using existing flake.lock (no input update)."
fi
"${cmd[@]}"

# echo "Building ISO..."
# nix build .#grajpap-iso

# iso_path="$(find /etc/nixos/result/iso -maxdepth 1 -type f -name '*.iso' | head -n 1)"
# if [ -z "${iso_path:-}" ]; then
#   echo "ISO build finished but no ISO file was found in result/iso"
#   exit 1
# fi

# ventoy_mount=""
# for candidate in /run/media/*/Ventoy; do
#   if [ -d "$candidate" ]; then
#     ventoy_mount="$candidate"
#     break
#   fi
# done

# if [ -n "$ventoy_mount" ]; then
#   echo "Refreshing ISO on Ventoy at $ventoy_mount"
#   rm -f "$ventoy_mount"/grajpap-live-*.iso
#   install -m 0644 "$iso_path" "$ventoy_mount/$(basename "$iso_path")"
#   sync "$ventoy_mount"
# else
#   echo "Ventoy drive not mounted, skipping ISO copy"
# fi

nh clean all --keep 3

git commit -m "$(date '+%Y-%m-%d %H:%M')"

echo "Rebuild finished"
git push -u origin main
