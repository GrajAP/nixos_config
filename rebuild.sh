#!/usr/bin/env bash
set -euo pipefail

cd /etc/nixos

alejandra /etc/nixos/ &>/dev/null \
  || ( alejandra /etc/nixos/ ; echo "formatting failed!" && exit 1 )

git add -A
nix-channel --update

echo "Checking flake"
nix flake check

nh os switch --update

echo "Cleaning old generations"
nh clean all --keep 3

git commit -m "$(date '+%Y-%m-%d %H:%M')"

echo "Rebuild finished"
git push -u origin main