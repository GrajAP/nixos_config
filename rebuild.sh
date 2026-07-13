#!/usr/bin/env bash
set -euo pipefail

cd /etc/nixos

echo "Checking flake"
nix flake check

echo "Building system"
nix build .#nixosConfigurations.grajpap.config.system.build.toplevel --no-link

echo "Applying validated system"
nh os switch
