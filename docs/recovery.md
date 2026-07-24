# Recovery and backup runbook

## Nextcloud

- RPO: at most 24 hours. The core Nextcloud job runs daily at 03:15 and the external-storage job at 04:15, both with a randomized delay.
- RTO target: four hours for restoring PostgreSQL, Nextcloud state and the external-storage mount on a prepared NixOS host.
- Core repository: `/mnt/HDD/Backups/restic/grajpap-nextcloud-core`.
- External-storage repository: `/mnt/HDD/Backups/restic/grajpap-nextcloud`.
- Repository password: `/var/lib/restic-nextcloud/password`. Copy this secret to an offline password manager. A copy on the same host is not disaster recovery.
- An off-host Restic repository must be configured when a remote destination is selected. Until then, disk theft or a host-wide incident is not covered.

The core job briefly enables maintenance mode, creates the PostgreSQL dump, disables maintenance mode immediately and then backs up the dump with `/var/lib/nextcloud`. Start it without attaching the shell, monitor it until `ActiveState` becomes `inactive`, then validate it before running the restore test:

```sh
systemctl start --no-block restic-backups-nextcloud.service
systemctl show restic-backups-nextcloud.service \
  --property=ActiveState --property=Result --property=ExecMainStatus
systemctl start collect-system-health.service
system-health | jq '.backup'
```

The potentially long external-storage job is separate and never enables Nextcloud maintenance mode. Start it without attaching the shell to the systemd job:

```sh
systemctl start --no-block restic-backups-nextcloud-storage.service
systemctl show restic-backups-nextcloud-storage.service \
  --property=ActiveState --property=Result --property=ExecMainStatus
```

The declared restore test restores the latest PostgreSQL dump, validates it with `pg_restore --list`, removes the temporary restore and records the last successful timestamp:

```sh
systemctl start restic-nextcloud-restore-test.service
systemctl show restic-nextcloud-restore-test.service --property=Result --property=ExecMainStatus
systemctl start collect-system-health.service
system-health | jq '.backup.restoreTest'
```

The service cleans its temporary directory on success and failure. The health report exposes the durable success timestamps without exposing the repository password or its protected state directory. Keep one encrypted copy of the Restic password away from this host.

The core backup also disables Nextcloud maintenance mode in `ExecStopPost`, including after a failed preparation. Confirm that cleanup in the unit journal before investigating a failure.

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
