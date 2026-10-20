# Fleet

One tailnet: `tail138448.ts.net`.

| Machine | What | Tailscale name | IP | SSH |
| --- | --- | --- | --- | --- |
| grajpap | PC, main desktop, heavy extras | `grajpap` | 100.123.219.96 | this machine |
| lenovo | 24/7 headless server: HomeNest, Nextcloud | `lenovo` | 100.110.204.8 | `ssh lenovo-user-ts` |
| dell | laptop, same desktop as PC minus heavy | `dellap` | 100.65.73.64 | `ssh dell` |
| POCO X4 Pro | adb test phone, USB on lenovo | `poco-x4-pro-5g` | 100.110.155.84 | `adb devices` on lenovo |
| Pixel 9a | personal phone, adb when docked | `grajpap-9a` | 100.106.96.44 | `adb devices` on the docked host |

## Rebuild

```bash
rebuild          # on each host, switches $(hostname)'s flake attr, commits
rebuild --check  # whole-fleet flake checks
fleet/status.sh  # health of reachable machines
```

Per machine: [lenovo.md](lenovo.md), [dell.md](dell.md), [poco.md](poco.md), [pixel.md](pixel.md).
