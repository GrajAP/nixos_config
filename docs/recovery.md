# Recovery and backup runbook

## Nextcloud

- RPO: at most 24 hours. The local Restic job runs daily at 03:15 with a randomized delay.
- RTO target: four hours for restoring PostgreSQL, Nextcloud state and the external-storage mount on a prepared NixOS host.
- Local repository: `/mnt/HDD/Backups/restic/grajpap-nextcloud`.
- Repository password: `/var/lib/restic-nextcloud/password`. Copy this secret to an offline password manager. A copy on the same host is not disaster recovery.
- An off-host Restic repository must be configured when a remote destination is selected. Until then, disk theft or a host-wide incident is not covered.

Validate the repository with `systemctl start restic-backups-nextcloud.service`, then inspect `journalctl -u restic-backups-nextcloud.service`. Restore into an empty directory with:

```sh
sudo install -d -m 0700 /var/lib/restic-nextcloud/restore-test
sudo RESTIC_PASSWORD_FILE=/var/lib/restic-nextcloud/password \
  restic -r /mnt/HDD/Backups/restic/grajpap-nextcloud restore latest \
  --target /var/lib/restic-nextcloud/restore-test
sudo -u postgres pg_restore --list \
  /var/lib/restic-nextcloud/restore-test/var/lib/restic-nextcloud/staging/nextcloud.pgdump
```

Do not leave Nextcloud in maintenance mode after a failed operation. Run `sudo nextcloud-occ maintenance:mode --off` if required.

## SSH activation stop-point

The declared SSH policy accepts keys only and exposes port 22 only through Tailscale. Before switching, install at least one tested public key in `~/.ssh/authorized_keys` and verify it from a second session. Do not activate the generation if that test is unavailable.

## Secure Boot and disk encryption

Secure Boot and LUKS require a separate maintenance window. Before migration:

1. Complete and test the Nextcloud restore above, plus an off-host copy.
2. Export the Windows recovery key and verify the manual GRUB Windows entry.
3. Prepare a NixOS installer USB and record the current working generation.
4. Enrol Secure Boot keys only after verifying every required out-of-tree module.
5. Repartition or migrate root and swap to LUKS only from rescue media. Keep the LUKS recovery key outside this host.

Rollback means booting the previous GRUB generation. Disk-layout rollback requires the tested Restic restore and cannot be achieved by changing a Nix option.
