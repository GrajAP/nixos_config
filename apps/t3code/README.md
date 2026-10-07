# t3code

T3 Code as a standalone flake: the desktop AppImage on workstations, the `t3`
CLI on headless servers, plus the two per-environment features that have no
store path and therefore are easy to miss — `t3 theme` and T3 Connect.

## Layout

| File | What it owns |
| --- | --- |
| `package.nix` | Every desktop-side derivation: AppImage launcher + fallback, `t3code-update`, `t3code-notify`, `t3code-theme`, `t3connect`. |
| `cli.nix` | `t3` for hosts with no desktop app: resolves to the runtime under `~/.t3` instead of carrying an Electron closure. |
| `modules/home-manager.nix` | Desktop profile: profile packages, AppImage update timer, CA bundle session variables, theme publishing. |
| `modules/nixos.nix` | Headless profile: `t3`, `t3connect`, `t3code-theme`, the `t3code.service` drop-in (PATH, nix-ld, CA bundle), theme publishing. |

`package.nix` is called with the caller's `pkgs`, so the fleet hosts keep their
own nixpkgs (unstable on `grajpap`, unstable on `lenovo` via
`specialArgs.unstablePkgs`) instead of dragging this flake's lock into theirs.
That is why the modules are plain files rather than functions of the flake
inputs: the same file is imported by the fleet and by `flake.nix` here.

`package.nix` also takes an optional `cli` argument — which `t3` the
non-desktop commands drive. Left unset it uses the nixpkgs `t3`, which is a
3.2 GB Electron closure; `modules/nixos.nix` passes `cli.nix` instead, and a
server ends up with a few hundred kilobytes of shell.

## Standalone use

```nix
{
  inputs.t3code.url = "path:./apps/t3code";

  # desktop
  home-manager.users.grajpap.t3code.enable = true;

  # headless
  t3code.enable = true;
}
```

## Environment that has to be stated somewhere

Three things about T3 Code on NixOS are not derivable and are easy to lose:

- **CA bundle.** The AppImage runs inside `appimage-run`'s FHS container, which
  cannot see `/etc/ssl`. Antigravity's ACP ships its own Python and OpenSSL, so
  without an explicit bundle every Gemini request fails with
  `SSL: CERTIFICATE_VERIFY_FAILED`, surfaced as `502 Bad Gateway`. The wrapper
  sets `SSL_CERT_FILE`, `NIX_SSL_CERT_FILE`, `NODE_EXTRA_CA_CERTS`,
  `REQUESTS_CA_BUNDLE` and `CURL_CA_BUNDLE`; on a server the unit needs the
  same, which is what `modules/nixos.nix` writes into the drop-in.
- **`nix-ld`.** The runtime under `~/.t3/runtime` is a plain npm tree, so its
  provider binaries are dynamically linked against a glibc NixOS does not put
  on the default loader path. `programs.nix-ld` covers the login shell but not a
  systemd unit, so the drop-in restates `NIX_LD` and `NIX_LD_LIBRARY_PATH`.
- **`cloudflared`.** T3 Connect tunnels through it. Both the wrapper and the
  drop-in point `T3CODE_CLOUDFLARED_PATH` at the Nix build.

## What is deliberately *not* declarative

`t3code.service` stays owned by `t3 service install`. It points at a versioned
runtime under `~/.t3/runtime` that `t3 update` replaces under the running
system; expressing that in NixOS would pin every switch to a version the user
already moved past. The flake writes the drop-in only, and `cli.nix` resolves
`t3` to whatever version `service-state.json` calls active, so the shell and the
service stop disagreeing — `t3 service status` was warning about exactly that
before.

The same holds for T3 Connect authorization: `t3connect login` / `t3connect
link` is an interactive Clerk OAuth flow and the credential lands in `~/.t3`.
`apps/whisprflow` and `apps/spark-corrector` follow the same split — flake
provides the derivation, the host decides when it runs.

## Commands

| Command | What it does |
| --- | --- |
| `t3code-desktop` | Refresh the AppImage if needed, then run it. |
| `t3code-update` | Download the newest preview AppImage release (SHA-256 checked). |
| `t3code-notify` | Run a command, then report duration and exit status via notify-send and ntfy. Aliased to `t3code`. |
| `t3` | The CLI. On a desktop, nixpkgs' build wrapped with the provider toolchain, relay, cloudflared and CA environment. On a server, `cli.nix`: the runtime the service is running, with cloudflared and the CA bundle. |
| `t3connect <login\|link\|status\|unlink\|logout\|publish>` | T3 Connect: the relay tunnel that makes this machine reachable from the phone and the other desktops. |
| `t3code-theme <show\|publish <file.json> [id]\|set <theme>\|clear>` | Environment-wide theme, published into `~/.t3/userdata/themes`. |

## Verification

```sh
cd apps/t3code && nix flake check   # alejandra, statix, deadnix
rebuild --check                     # fleet checks, both hosts evaluate
```