# dell — day-to-day laptop (uni notes)

Dell laptop, NixOS, the machine you actually sit in front of: same desktop as
`grajpap` (Hyprland, Quickshell, binds, shell, theme) but without the heavy
PC-only extras — no Android Studio/SDK, no games, no server/hosting — and
tuned for battery life first.

- **Flake attr**: `nixosConfigurations.dell` via the shared `mkHost` path
  (`hosts/dell/`)
- **nixpkgs**: same unstable input as the PC (keeps the desktop 1:1)
- **Tailscale**: `dellap` → 100.65.73.64
- **user**: `grajpap` (uid 1000) — the shared `system/core/users.nix`,
  `configuration.nix` and SSH `AllowUsers` all hardcode this name
- **kernel**: linuxPackages_zen, same as the rest of the fleet

## Status: one manual step left, then fully remote

`hosts/dell/default.nix` and the flake entry are done and evaluated. The only
thing missing is `hosts/dell/hardware-configuration.nix`, which cannot be
invented — a wrong root UUID builds cleanly and then leaves the laptop
unbootable. It currently `throw`s with the harvest command, so
`rebuild --check` fails loudly on `nixosConfigurations.dell` and only there.

### Step 1 — unlock SSH (on the dell, at its own console)

Password login cannot work, by fleet policy:
`system/wayland/services.nix` sets `PasswordAuthentication = false`,
`KbdInteractiveAuthentication = false` and `AllowUsers = ["grajpap"]`, and
dell's sshd confirms it — it only advertises `publickey,keyboard-interactive`
and PAM returns no challenge, so there is no prompt for a password. The only
supported way in is a key.

Run this once, locally on the dell:

```sh
git clone https://github.com/GrajAP/nixos_config.git /tmp/fleet
sudo /tmp/fleet/fleet/dell-bootstrap.sh
```

The clone needs GitHub credentials, because the repository is private. If
that is inconvenient on the dell, skip it entirely and paste the inline block
below -- that is the only part that matters and it needs no repository.

`fleet/dell-bootstrap.sh` is idempotent and touches nothing but the user
account, `authorized_keys`, and the sshd unit. It creates `grajpap` if
missing, adds lenovo's fleet public key, and grants NOPASSWD sudo (root SSH
stays disabled, as everywhere else).

If dell has no git/the repo yet, the whole script is also inline here —
its only real content is one `useradd`, one `authorized_keys` line and one
sudoers file.

### Step 2 — everything else is remote

From lenovo, once the key lands:

```sh
ssh -i ~/.ssh/id_ed25519_lenovo_fleet dell@dellap
```

Then, still from lenovo:

1. `sudo nixos-generate-config --show-hardware-config > /tmp/hw.nix` on dell,
   copy it to `hosts/dell/hardware-configuration.nix` in the repo.
2. `rebuild --check` from lenovo — the dell entry now evaluates.
3. **Switch on the dell itself** (`rebuild` there, or
   `nixos-rebuild switch --flake .#dell`). Never cross-install.

## Design notes

- `fleet.heavy.enable = false` — no gaming, Android Studio, Nextcloud
  hosting, restic, health reporting or PC data disks.
- `fleet.dualBoot = false` — new option in `system/core/bootloader.nix`. It
  gates the hand-written "Windows Boot Manager" GRUB entry, GRUB's `default`
  index, `boot.supportedFilesystems = ["ntfs"]`, and four kernel parameters
  (`nvme.noacpi=1`, `pcie_aspm=off`, two NVMe timeouts) that exist only to
  coax the PC's dual-boot disk out of an unready Realtek controller. On a
  battery machine `pcie_aspm=off` is actively harmful, so dell wants them
  gone. `grajpap` sets `fleet.dualBoot = true` and is unaffected.
- Zen kernel kept. Good scheduler/preemption for interactive work, and it is
  the best-behaved kernel for idle power.
- Battery: `cpuFreqGovernor = "powersave"` (the PC pins `performance`; that is
  a desktop setting and only costs idle hours here), TLP as the sole power
  daemon, `PCIE_ASPM = powersupersave` on both AC and battery,
  `RUNTIME_PM = on`, and 40/80 charge thresholds with upower enabled. The
  sleep targets are *not* masked — the opposite of lenovo, which never
  suspends.
- `services.openssh` is the shared key-only desktop policy; no override.

### No clone required

The bootstrap only adds one SSH key, so there is nothing to clone. If you
would rather not paste a block into the dell terminal, the whole of
`fleet/dell-bootstrap.sh` is this single copy-pasteable command:

```sh
sudo bash -c '
set -e
id grajpap >/dev/null 2>&1 || useradd -m -s "$(command -v bash || command -v sh)" -c "fleet user" grajpap
for g in wheel sudo docker systemd-journal audio plugdev storage video input networkmanager; do
  getent group "$g" >/dev/null 2>&1 && usermod -aG "$g" grajpap || true
done
echo "grajpap ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/grajpap
chmod 0440 /etc/sudoers.d/grajpap
h=$(getent passwd grajpap | cut -d: -f6)
install -d -m 0700 -o grajpap -g grajpap "$h/.ssh"
touch "$h/.ssh/authorized_keys"
grep -qF "lenovo-fleet-to-dell" "$h/.ssh/authorized_keys" || printf "%s\n" "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBnc4+4bYtx2q/y/f2k6BAh3aXyMV4m8c/V1wtprDa1p lenovo-fleet-to-dell" >> "$h/.ssh/authorized_keys"
chown grajpap:grajpap "$h/.ssh/authorized_keys"
chmod 0600 "$h/.ssh/authorized_keys"
u=$(systemctl list-unit-files 2>/dev/null | grep -oE "^sshd?\.service" | head -1); systemctl enable --now "${u:-sshd.service}" || true
echo "OK: $h/.ssh/authorized_keys ready"
'
```

Cloning only matters if you would rather review the file first. Note that
`curl`ing the script from `raw.githubusercontent.com` does **not** work: the
repository is private, so raw fetches are unauthenticated and return 404.
Use the inline block above, or clone with credentials.

## Is the SSH key in this script a leak?

No. `fleet_pubkey` is the **public** half of the lenovo -> dell keypair.
Publishing a public key is the entire point: it is what goes into
`authorized_keys`, and it is designed to be handed out. It cannot be used to
authenticate -- anyone holding it still needs the private key, which stays in
`~/.ssh/id_ed25519_lenovo_fleet` on lenovo and is never committed (only the
`.pub` file exists in the repo, and the repo is private anyway).

The key is also not fleet-wide: it is a single-purpose keypair generated for
lenovo -> dell, and it is used by nothing else.
