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
#   1. Makes sure the fleet user `grajpap` exists (wheel, NOPASSWD sudo).
#      The shared system/core/users.nix and configuration.nix both hardcode
#      that name, and the shared SSH config allows only that user.
#   2. Adds lenovo's fleet PUBLIC key to the user's authorized_keys.
#   3. Ensures the sshd unit is enabled and running.
#
# It does NOT touch the disk layout, bootloader, shell or password of an
# existing user, and it never disables key-only SSH.
set -euo pipefail

readonly fleet_user=grajpap
readonly fleet_pubkey='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBnc4+4bYtx2q/y/f2k6BAh3aXyMV4m8c/V1wtprDa1p lenovo-fleet-to-dell'

if [[ $EUID -ne 0 ]]; then
  printf 'This script needs root. Re-run with: sudo %q\n' "$0" >&2
  exit 1
fi

# NixOS has no `sudo` group at all -- only `wheel`. Adding a group that does
# not exist makes usermod fail outright, so only ever add groups that are
# really present. (The NOPASSWD rule below is the part that actually grants
# sudo, and it does not depend on any group.)
printf '== fleet user ==\n'
if id "$fleet_user" >/dev/null 2>&1; then
  printf '  %s already exists (uid %s)\n' "$fleet_user" "$(id -u "$fleet_user")"
  # Deliberately not touching the shell: an existing account may be set up
  # for zsh, and /bin/bash does not necessarily exist on NixOS.
else
  shell_path="$(command -v bash || command -v sh)"
  useradd --create-home --shell "$shell_path" --comment 'fleet primary user' "$fleet_user"
  printf '  created %s (uid %s, shell %s)\n' "$fleet_user" "$(id -u "$fleet_user")" "$shell_path"
fi

for group in wheel sudo docker systemd-journal audio plugdev storage video input networkmanager; do
  if getent group "$group" >/dev/null 2>&1; then
    # Non-fatal on purpose: a failure here must not abort the script before
    # the authorized_keys step, which is the part that actually matters.
    usermod --append --groups "$group" "$fleet_user" \
      || printf '  warning: could not add group %s\n' "$group" >&2
  fi
done
printf '  groups: %s\n' "$(id -Gn "$fleet_user")"

# Passwordless sudo, matching the other fleet hosts (root SSH stays disabled).
install \
  --mode 0440 \
  --owner root \
  --group root \
  /dev/stdin "/etc/sudoers.d/$fleet_user" <<<"$fleet_user ALL=(ALL:ALL) NOPASSWD: ALL"

printf '\n== lenovo access ==\n'
home="$(getent passwd "$fleet_user" | cut -d: -f6)"
[[ -d $home ]] || home="/home/$fleet_user"
ssh_dir="$home/.ssh"
install -d -m 0700 -o "$fleet_user" -g "$fleet_user" "$ssh_dir"

authorized="$ssh_dir/authorized_keys"
touch "$authorized"
if grep -qF "$fleet_pubkey" "$authorized"; then
  printf '  fleet key already authorized\n'
else
  printf '%s\n' "$fleet_pubkey" >>"$authorized"
  printf '  added fleet public key\n'
fi

chown "$fleet_user:$fleet_user" "$authorized"
chmod 0600 "$authorized"
chmod 0700 "$ssh_dir"

printf '\n== sshd ==\n'
if command -v systemctl >/dev/null 2>&1; then
  # NixOS names the unit `sshd`; most other distros name it `ssh`.
  sshd_unit="$(systemctl list-unit-files 2>/dev/null | awk '/^sshd?\.service/ {print $1; exit}')"
  sshd_unit="${sshd_unit:-sshd.service}"
  systemctl enable --now "$sshd_unit" || true
  printf '  %s: %s\n' "$sshd_unit" "$(systemctl is-active "$sshd_unit" 2>/dev/null || echo unknown)"
fi

if tailscale status >/dev/null 2>&1; then
  printf '  tailscale: %s\n' "$(tailscale ip -4 2>/dev/null || echo up)"
else
  printf '  tailscale: NOT INSTALLED -- remote install will not be possible\n'
fi

cat <<'EOF'

Done. Now go back to lenovo and run:

  ssh -i ~/.ssh/id_ed25519_lenovo_fleet dell@dellap

If that works, everything else (hardware config harvest, hosts/dell/, the
switch) is handled remotely.
EOF
