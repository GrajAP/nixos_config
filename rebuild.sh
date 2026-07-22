#!/usr/bin/env bash
set -euo pipefail

cd /etc/nixos

alejandra /etc/nixos/ &>/dev/null \
  || ( alejandra /etc/nixos/ ; echo "formatting failed!" && exit 1 )

git add -A

echo "Checking flake"
nix flake check

nh os switch --update

echo "Cleaning old generations"
systemctl start t3code-nh-clean.service

git add -A
git commit -m "$(date '+%Y-%m-%d %H:%M')"

echo "Rebuild finished"
git push -u origin main
