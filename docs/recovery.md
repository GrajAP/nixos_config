# Recovery and backup runbook

## Nextcloud

Nextcloud is hosted on **lenovo**, not on the PC, so this section is split: the
data this runbook protects, and where it now lives.

### lenovo: calendar, tasks, notes

- Data: `/var/lib/nextcloud/data` plus the PostgreSQL database.
- RPO/RTO: **not currently covered.** The nightly job in
  `hosts/lenovo/modules/backup.nix` backs up `/opt/homenest/data` and
  `/etc/nixos`; the Nextcloud datadir is not in it. Until that changes, a
  `rm -rf` in the datadir is unrecoverable.
- Restore:

  ```sh
  sudo systemctl stop phpfpm-nextcloud.service
  sudo restic -r /var/lib/restic/homenest restore latest --include /var/lib/nextcloud
  ```

  A PostgreSQL dump has to be taken with `pg_dump`; restic restores files, not a
  consistent database image, so stop the service first.

### grajpap: /mnt/Storage only

The PC used to host Nextcloud. It does not any more — `system/sync` is gone and
`system/desktop` is what replaced it. What is left on this host is the backup of
`/mnt/Storage`, the 214 GiB external disk, which is grajpap's own data and has
nothing to do with the Nextcloud move.

- RPO: at most 24 hours. The job runs daily at 04:15 with a randomized delay.
- Repository: `/mnt/HDD/Backups/restic/grajpap-nextcloud`. The name still says
  Nextcloud and no longer describes the contents; it was kept so the repository
  password in the state directory below keeps opening the existing history.
- Repository password: `/var/lib/restic-nextcloud/password`. Copy this secret to
  an offline password manager. A copy on the same host is not disaster recovery.
- The state directory and repository are on the same disk as some of the data.
  That covers against accidental deletion and a bad deploy, not against disk
  failure. An off-host repository is still missing on both hosts.

```sh
systemctl start --no-block restic-backups-storage.service
systemctl show restic-backups-storage.service \
  --property=ActiveState --property=Result --property=ExecMainStatus
systemctl start collect-system-health.service
system-health | jq '.backup'
```

There is no declared restore test any more. The quarterly one that validated
the PostgreSQL dump went with the instance it was testing. Validate a restore
by hand until a replacement exists:

```sh
sudo restic -r /mnt/HDD/Backups/restic/grajpap-nextcloud snapshots
sudo restic -r /mnt/HDD/Backups/restic/grajpap-nextcloud \
  restore latest --target /tmp/restore-check
```

The health report exposes the durable success timestamp without exposing the
repository password or its protected state directory. Keep one encrypted copy
of the Restic password away from this host.

## Desktop calendar widget credentials

`quickshell-calendar` authenticates with an app password that lenovo mints,
because `occ` only runs locally. After a switch on lenovo, or after the monthly
rotation, each desktop has to collect it again:

```sh
mkdir -p ~/.config/quickshell
ssh lenovo-user sudo nextcloud-quickshell-token-print \
  > ~/.config/quickshell/nextcloud-lenovo-app-password
chmod 600 ~/.config/quickshell/nextcloud-lenovo-app-password
```

An empty calendar with an error strip at the bottom of the widget means this
file is missing or stale. A widget with no error strip and no events means the
query ran and genuinely found nothing.

## SSH activation stop-point

The declared SSH policy accepts keys only and exposes port 22 only through
Tailscale. Before switching, install at least one tested public key in
`~/.ssh/authorized_keys` and verify it from a second session. Do not activate
the generation if that test is unavailable.

## Secure Boot and disk encryption

Secure Boot and LUKS require a separate maintenance window. Before migration:

1. Complete and test a restore from both repositories, plus an off-host copy.
2. Export the Windows recovery key and verify the manual GRUB Windows entry.
3. Prepare a NixOS installer USB and record the current working generation.
4. Enrol Secure Boot keys only after verifying every required out-of-tree module.
5. Repartition or migrate root and swap to LUKS only from rescue media. Keep the
   LUKS recovery key outside this host.

Rollback means booting the previous GRUB generation. Disk-layout rollback
requires the tested Restic restore and cannot be achieved by changing a Nix
option.