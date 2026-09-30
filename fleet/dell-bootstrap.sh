#!/usr/bin/env bash
#
# One-shot bootstrap for the dell laptop, to be run LOCALLY on the machine
# (at its own console), not over SSH. It only unlocks remote management --
# harvesting hardware config and switching the fleet profile are done from
# lenovo afterwards.
#
# It is idempotent: re-running it is safe.
#
# What it does:
#   1. Makes sure the fleet user `grajpap` exists (uid 1000, wheel + sudo).
#      The shared system/core/users.nix and configuration.nix both hardcode
#      that name, and the shared SSH config allows only that user.
#   2. Adds lenovo's fleet public key to the user's authorized_keys.
#   3. Enables key-only openssh (this is what PasswordAuthentication = false
#      in the shared desktop config already does -- this script just makes
#      sure the key is present, so the same policy holds either way).
#
# It does NOT touch the disk layout, bootloader or the existing system.
set -euo pipefail

readonly fleet_user=grajpap
readonly fleet_pubkey='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBnc4+4bYtx2q/y/f2k6BAh3aXyMV4m8c/V1wtprDa1p lenovo-fleet-to-dell'

if [[ $EUID -ne 0 ]]; then
  printf 'This script needs root. Re-run with: sudo %q\n' "$0" >&2
  exit 1
fi

printf '== fleet user ==\n'
if id "$fleet_user" >/dev/null 2>&1; then
  printf '  %s already exists (uid %s)\n' "$fleet_user" "$(id -u "$fleet_user")"
else
  useradd \
    --create-home \
    --shell /bin/bash \
    --comment 'fleet primary user' \
    "$fleet_user"
  printf '  created %s (uid %s)\n' "$fleet_user" "$(id -u "$fleet_user")"
fi

usermod --append --groups wheel,sudo "$fleet_user"
printf '  groups: %s\n' "$(id -Gn "$fleet_user")"

# Passwordless sudo, matching the other fleet hosts (root SSH stays disabled).
install \
  --mode 0440 \
  --owner root \
  --group wheel \
  /dev/stdin "/etc/sudoers.d/$fleet_user" <<<"$fleet_user ALL=(ALL:ALL) NOPASSWD: ALL"

printf '\n== lenovo access ==\n'
home="$(getent passwd "$fleet_user" | cut -d: -f6)"
ssh_dir="$home/.ssh"
install -d -m 0700 -o "$fleet_user" -g "$fleet_user" "$ssh_dir"

authorized="$ssh_dir/authorized_keys"
if [[ -f $authorized ]] && grep -qF "$fleet_pubkey" "$authorized"; then
  printf '  fleet key already authorized\n'
else
  # touch before append so the file exists with safe ownership/perms
  touch "$authorized"
  printf '%s\n' "$fleet_pubkey" >>"$authorized"
  printf '  added fleet key\n'
fi

chown "$fleet_user:$fleet_user" "$authorized"
chmod 0600 "$authorized"
chmod 0700 "$ssh_dir"

printf '\n== sshd ==\n'
if command -v systemctl >/dev/null 2>&1; then
  sshd_unit="$(command -v sshd >/dev/null 2>&1 && echo sshd || echo ssh)"
  systemctl enable --now "$sshd_unit" || true
  printf '  sshd: %s\n' "$(systemctl is-active "$sshd_unit" 2>/dev/null || echo unknown)"
fi

if tailscale status >/dev/null 2>&1; then
  printf '  tailscale: %s\n' "$(tailscale status --self 2>/dev/null || tailscale ip -4 2>/dev/null || echo up)"
else
  printf '  tailscale: NOT INSTALLED -- remote install will not be possible\n'
fi

cat <<'EOF'

Done. Now go back to lenovo and run:

  ssh -i ~/.ssh/id_ed25519_lenovo_fleet dell@dellap

If that works, everything else (hardware config harvest, hosts/dell/, flake
entry, the switch) is handled remotely.
EOF
