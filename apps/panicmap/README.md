# PanicMap

The backend behind `hy.be-spotted.org`, served by this machine and by nothing
else. The Cloudflare tunnel in `~/.cloudflared/config.yml` points that hostname
at `127.0.0.1:8000`, so this module is the difference between the app working
and not.

## What runs

| Unit | What it is |
| --- | --- |
| `panicmap-api` | the Fastify API on `:8000` |
| `panicmap-worker` | the 60-second escalation sweep |
| `panicmap-api-update.timer` | every 3 min: fetch the checkout, fast-forward it, restart if anything moved |
| `panicmap-api-reload.timer` | every 1 min: restart if a file on disk moved |

Both timers run [`panicmap-api-update`](./panicmap-api-update), which pulls,
fingerprints the sources and restarts only when the fingerprint changed. The
reload timer is the same script with `--sources-only`, so a local edit never
waits on GitHub and never spends a request on it.

There is no packaging here on purpose. `packages.api` in the PanicMap flake
builds the *Python* backend that `origin/main` still carries, while the code
that actually answers requests is an uncommitted Node rewrite in a checkout on
this disk. Wrapping the checkout is what keeps "what is live" and "what is in
the tree" the same question.

`npm ci` and `tsc` run in the unit's `ExecStartPre`, and only when the lockfile
or a source is newer than `dist/server.js`, so a restart that has nothing to
compile costs nothing. Drizzle migrations run there too: they are idempotent,
and a deploy step is a step somebody forgets.

The checkout does not typecheck — 15 errors, all `request.body is of type
unknown` in the route files, because the Zod type provider is not wired into
those handlers. `npm run dev` is tsx and never ran tsc, so nobody has seen them.
`tsc` emits anyway, so the build script reports the errors, checks that
`dist/server.js` was actually rewritten, and serves it. A failed *emit* still
fails the unit.

## Configuration

Enabled from `hosts/grajpap/default.nix`:

```nix
panicmap = {
  enable = true;
  autoUpdate.enable = true;
};
```

Everything else has a default worth knowing:

- `sourceDir` — the checkout, `/mnt/SSD2/dev/hackyeah2026`. Changing the branch
  or pulling commits is how the backend is updated; nothing is copied into the
  Nix store.
- `envFile` — `/home/grajpap/.config/panicmap/api.env`, mode 0600, holding the
  Clerk keys, the invite signing key and the Expo token. It lives outside this
  repository because `rebuild.sh` runs gitleaks over `/etc/nixos` and the nightly
  auto-rebuild pushes whatever it finds there.
- `database.*` — the system Postgres cluster, role and database `panicmap`,
  reached over the unix socket in `/run/postgresql` with `trust` for that one
  role. Not TCP: Docker publishes the bespotted Postgres on 127.0.0.1:5432, so
  the system cluster cannot bind the address it would listen on. Not a cluster
  of its own: nixpkgs has no `services.postgresql.instances`, and Nextcloud
  lives in the one that is there. `DATABASE_URL` is generated from these options
  rather than written into the env file, so the socket path is stated once.
- `user` — `grajpap`. `npm run build` writes `dist/` into the checkout, so a
  service account could not rebuild what it serves.

## What is not automated

The pull is refused while the working tree is dirty, and right now it always
is: the Node backend is uncommitted work on branch `init`. Until that is pushed
somewhere, `panicmap-api-update` logs `working tree has local changes, not
pulling` every three minutes and serves the checkout as it is on disk. The
reload timer still picks up local edits.

That is the whole reason the fingerprint exists. Restarting the public API on a
half-applied pull, or once per file an editor writes, is worse than serving a
tree that is a minute behind.

## Operating it

```bash
systemctl status panicmap-api panicmap-worker
journalctl -u panicmap-api -f
systemctl start panicmap-api-update.service   # pull + restart, now
nixos-rebuild switch --flake .#grajap         # after editing this module
```

`panicmap-api.service` runs migrations before it serves, so a new drizzle
migration lands with the commit that needs it.