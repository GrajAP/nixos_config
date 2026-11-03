# Recovery and backup runbook

## Nextcloud

Nextcloud is hosted on **lenovo**, not on the PC, so this section is split: the
data this runbook protects, and where it now lives.

### lenovo: calendar, tasks, notes

- Data: `/var/lib/nextcloud` (`data/`, `config/`, `secrets/`) plus the
  `nextcloud` PostgreSQL database. Calendars and tasks live in the database,
  notes are files under `data/grajpap/files`.
- Backup: `nextcloud-backup.service` in `hosts/lenovo/modules/backup.nix`, every
  night at 03:50 (up to 10 min random delay). It turns maintenance mode on,
  writes a `pg_dump` to `/var/lib/homenest-backup/nextcloud.sql`, runs restic on
  `/var/lib/nextcloud` plus that dump, then turns maintenance mode off. Previews
  (`data/appdata_*/preview`) are skipped, Nextcloud regenerates them. Same
  repository and password as HomeNest, snapshots are tagged `nextcloud`, a
  failure alerts through `server-alert@nextcloud-backup`.
- RPO: 24 hours. RTO: about 10 minutes. The repository is on the same disk, so
  this covers mistakes and bad deploys, not disk failure.
- Restore:

  ```sh
  sudo restic -r /var/lib/restic/homenest snapshots --tag nextcloud
  sudo restic -r /var/lib/restic/homenest restore latest --tag nextcloud --target /tmp/nc
  sudo nextcloud-occ maintenance:mode --on
  sudo systemctl stop nextcloud-cron.timer phpfpm-nextcloud.service nextcloud-notify_push.service

  sudo rsync -a --delete /tmp/nc/var/lib/nextcloud/data/ /var/lib/nextcloud/data/
  sudo cp -a /tmp/nc/var/lib/nextcloud/config/config.php /var/lib/nextcloud/config/
  sudo chown -R nextcloud:nextcloud /var/lib/nextcloud/data /var/lib/nextcloud/config

  sudo -u postgres dropdb --force nextcloud
  sudo -u postgres createdb -O nextcloud nextcloud
  sudo -u postgres psql -d nextcloud -v ON_ERROR_STOP=1 \
    -f /tmp/nc/var/lib/homenest-backup/nextcloud.sql

  sudo systemctl restart redis-nextcloud.service
  sudo systemctl start phpfpm-nextcloud.service nextcloud-notify_push.service nextcloud-cron.timer
  sudo nextcloud-occ maintenance:mode --off
  sudo nextcloud-occ maintenance:data-fingerprint
  sudo rm -rf /tmp/nc
  ```

  `--delete` on `data/` drops the preview cache, which is expected.
  `config.php` holds the instance secret and password salt, restore it together
  with the database. `data-fingerprint` tells sync clients the server went back
  in time. The backed up `config.php` has maintenance mode on, so the
  `--off` step is required.

### grajpap: /mnt/Storage only

The PC used to host Nextcloud. It does not any more, `system/sync` is gone and
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