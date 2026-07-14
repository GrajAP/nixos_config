# WhisprFlow CLI

Local push-to-talk dictation for Wayland. It records from PipeWire, transcribes
locally with `faster-whisper`, lets you correct the text, learns correction
pairs, copies the result and types it into the previously focused field.

## Run

```bash
nix run . -- start
nix run . -- stop
```

Install from a repository containing this directory:

```bash
nix profile install 'github:grajpap/nixos_config?dir=apps/whisprflow'
```

Commands:

- `whisprflow start` starts recording.
- `whisprflow stop` stops, transcribes, opens review and pastes.
- `whisprflow toggle` switches between start and stop.
- `whisprflow status` prints `recording` or `idle`.
- `whisprflow copy` copies the last transcript without typing it.
- `whisprflow learn` learns from the last transcript and current clipboard.

Example Hyprland hold binding:

```ini
bind = , PAUSE, exec, whisprflow start
bindr = , PAUSE, exec, whisprflow stop
```

The default model is `small`, with Polish and English candidates. Override it
with `WHISPER_MODEL`, `WHISPER_LANGUAGE`, `WHISPER_LANGS` or
`WHISPER_SOURCE`. State and learned corrections can be relocated with
`WHISPR_STATE_DIR` and `WHISPR_DATA_DIR`. `ydotoold` is optional; `wtype` is
used as a fallback and the transcript remains in the clipboard if direct
typing fails.
