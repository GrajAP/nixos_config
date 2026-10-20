# lenovo: 24/7 headless server

- What: HomeNest (Docker, Caddy :80), Nextcloud under `/nextcloud`, restic backups, HTML plan uploads at `/plans`
- Config: `hosts/lenovo/`, nixpkgs 25.11 stable + `unstablePkgs`, no home-manager
- IP: `192.168.1.136` LAN, `100.110.204.8` tailnet
- SSH: `ssh lenovo-user-ts` (or `lenovo-user` on the LAN), user `grajpap`, NOPASSWD sudo, root SSH disabled
- Rebuild: `./rebuild.sh` (switches `#lenovo`)

## Notes

- WiFi is eduroam via `hosts/lenovo/modules/wifi.nix`; credentials go to
  `/var/lib/eduroam/eduroam.env`, never in the repo.
- Health audit details live in this file's history; the box has no battery, dies
  instantly on power loss once a minute passes.
- HTTPS: `https://lenovo.tail138448.ts.net/` via `tailscale serve` + Caddy.
