#!/bin/bash
set -euo pipefail
cd /etc/nixos/

alejandra /etc/nixos/ &>/dev/null \
  || ( alejandra /etc/nixos/ ; echo "formatting failed!" && exit 1 )

git add -A

echo "NixOS Rebuilding..."

nix-channel --update
nh os switch --update
nh clean all --keep 3

git commit -m "$(date '+%Y-%m-%d %H:%M')"

echo "Rebuild finished"
git push -u origin main
