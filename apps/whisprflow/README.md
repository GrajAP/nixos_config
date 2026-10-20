# WhisprFlow: local Wispr Flow clone

Push-to-talk dictation for Wayland/Hyprland. Everything runs on your machine
except one optional LLM cleanup pass (your own `codex` CLI plan, no extra API
key). Native Whisper on CPU + resident daemon = hot latency on par with
commercial cloud dictation.

## How it works

1. `whisprflow start` records 16 kHz mono PCM via PipeWire.
2. While recording, a background loop posts live partial transcripts every
   ~3.5 s and shows them as `≈ …` preview notifications (`WHISPER_PARTIALS=1`
   default).
3. `whisprflow stop` finishes the clip, drives the resident daemon
   (`asr.py serve`, unix socket, model kept warm), and gets text.
4. Optional Spark cleanup (`spark-corrector filter --mode whisprflow`,
   `WHISPER_SPARK_CORRECTION=1` default) fixes punctuation, casing and voice
   structure commands through your `codex` CLI (`gpt-5.3-codex-spark`).
5. The text is typed straight into the focused window (`wtype`), like the real
   Wispr Flow. Set `WHISPER_PASTE_MODE=clipboard` to fall back to
   Ctrl+V from the clipboard.

## Commands

| Command | What it does |
| --- | --- |
| `whisprflow start` | Start recording |
| `whisprflow stop` | Stop, transcribe, clean up, paste |
| `whisprflow toggle` | Start or stop |
| `whisprflow cancel` | Stop and discard the draft |
| `whisprflow review` | Re-edit the last transcript in the popup, then re-paste |
| `whisprflow status` | `recording`/`idle` plus daemon and model state |
| `whisprflow copy` | Copy the last transcript |
| `whisprflow learn` | Learn dictionary/corrections from your edits |
| `whisprflow dict add TERM` / `remove TERM` / `clear` / `list` | Manage the dictionary |
| `whisprflow stats` | Words, sessions and dictation minutes (today/week/all) |

Default bindings (Sway/Hyprland differ, see `voice.nix`): `Pause` or `SRGR`
push-to-talk with `stop` on release.

## Voice structure commands

Handled by Spark when it is on, and by a built-in local fallback otherwise:

- "nowy akapit" / "new paragraph", paragraph break
- "nowa linia" / "new line", line break
- "punkt pierwszy|drugi|…", "point one|two", numbered list items
- "whisprflow lista: item one, item two, item three", bullet list
- "blok kodu [lang]" / "code block" / "snippet", fenced code block
- "redo"/"ponów", "use parentheses …", last-chunk fixes
- Corrections & dictionary: `~/.config/whisprflow/corrections.txt` and
  `dictionary.txt` (learned automatically after you edit pasted text).

## Environment knobs

| Variable | Default | Purpose |
| --- | --- | --- |
| `WHISPER_MODEL` | `large-v3-turbo` | Any faster-whisper model id or local path |
| `WHISPER_LANGS` | `pl,en` | Languages to force-decode in pass 1 |
| `WHISPER_DUAL` | `1` | `1` retry other language when score is low, `2` always both |
| `WHISPER_MIN_SCORE` | `-0.47` | Duration-weighted logprob gate for the retry |
| `WHISPER_BEAM_SIZE` | `5` | CT2 beam |
| `WHISPER_CPU_THREADS` | `12` | CT2 worker threads |
| `WHISPER_VAD` | `1` | Silero VAD filtering |
| `WHISPER_LANGUAGE` | empty | Force a single language |
| `WHISPER_PARTIALS` | `1` | Live partial previews while recording |
| `WHISPER_PARTIAL_INTERVAL` | `3.5` | Seconds between partial attempts |
| `WHISPER_PARTIAL_TAIL` | `8` | How much of the tail each partial keeps |
| `WHISPER_SPARK_CORRECTION` | `1` | LLM cleanup via Spark before pasting |
| `WHISPER_PASTE_MODE` | `type` | `type` via `wtype`, or `clipboard` Ctrl+V |
| `WHISPER_REVIEW` | `0` | Open the review popup before pasting |
| `WHISPER_GAIN` / `WHISPER_GAIN_CAP` | auto | Normalization gains |

The daemon reads defaults from `~/.config/whisprflow/serve.env` (systemd unit
sets sane fleet defaults) and accepts per-request overrides, that's how
partials use a cheaper fast pass (`beam=1`, single language, tail only).

## Daemon

`asr.py serve` keeps the model and VAD resident so repeated dictations skip
the ~2.6 s model load. `whisprflow` probes the socket and spawns the daemon
on demand (flock-guarded); systemd users get
`systemd --user status whisprflow-serve` with `Restart=on-failure` and a
15-minute idle self-exit in foreground mode.

## Diagnostics

- `~/.local/share/whisper-record-v2/whisper.log`, one JSON line per decode
  attempt with duration/RMS/gain and language scores. Delete it when it
  exceeds ~5 MB.
- `~/.local/share/whisper-record-v2/failed/`, any clip that produced no text
  so you can replay exactly what failed.
- `~/.local/share/whisper-record-v2/last-error.log`, stderr of the last
  failing transcription.
- `whisprflow stats`, a compact usage summary.

## Build & deploy

The flake (`apps/whisprflow/flake.nix`) installs from any machine:

```bash
nix profile install github:grajpap/nixos_config#whisprflow  # or path:.
```

Inside the fleet, `home/features/voice.nix` installs it on desktop hosts
together with `spark-corrector`, and ships the `whisprflow-serve` user
service. Rebuild with `./rebuild.sh`.
