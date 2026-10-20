# WhisprFlow CLI

Local push-to-talk dictation for Wayland, in the style of Wispr Flow. Press
start, speak (whispering at 2–3 cm works), press stop, and the polished text
lands in the field you were typing in — no popping up windows. Everything runs
locally and free: PipeWire recording, `faster-whisper` transcription through a
resident engine, continuous language-switching between Polish and English,
explicit spoken formatting, and correction learning from every transcript.

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
- `whisprflow stop` stops, transcribes and pastes into the focused field.
Pass `WHISPER_REVIEW=1` to bring back the review popup before the paste.
- `whisprflow toggle` switches between start and stop.
- `whisprflow status` prints `recording` or `idle`.
- `whisprflow copy` copies the last transcript without typing it.
- `whisprflow learn` learns from the last transcript and current clipboard.

Example Hyprland hold binding:

```ini
bind = , PAUSE, exec, whisprflow start
bindr = , PAUSE, exec, whisprflow stop
```
The default model is `large-v3-turbo` (downloaded from Hugging Face on first
use). Set `WHISPER_MODEL` to use another faster-whisper model (use `small` on
slower machines; `large-v3-turbo` is CPU-heavy but much more accurate on quiet
speech). By default the clip is first decoded forced to the primary language
(`WHISPER_LANGS`, default `pl,en`). When that pass is not confident
(below `WHISPER_MIN_SCORE`, default `-0.47`), the clip is decoded again in the
other language and the more confident hypothesis wins, so the result is always
one of the two languages exactly. `WHISPER_DUAL=2` always runs both passes,
`WHISPER_DUAL=0` uses automatic language detection in a single pass. Force a
language with `WHISPER_LANGUAGE`, adjust the search with `WHISPER_BEAM_SIZE`
(default `5`), set `WHISPER_MIN_SCORE`, or override `WHISPER_MODEL`,
`WHISPER_LANGS` and `WHISPER_SOURCE`.
Quiet close-range dictation is recognized too: the clip is auto-gained to a
normal speaking level before decoding, the VAD threshold is relaxed
(`WHISPER_VAD=0` skips the detector entirely), borderline-silent segments are
accepted more readily, and clipped peaks are soft-limited — so holding the mic
2–3 cm from your mouth and whispering works.
Every run is logged with its audio stats and per-language confidence to
`$WHISPR_DATA_DIR`/`whisper.log`; when nothing is recognized, the recording is
kept as `$WHISPR_DATA_DIR`/`failed/<timestamp>.wav` for diagnostics.
Transcription runs through a resident CPU engine: `whisprflow start` warms up a
background daemon (`$WHISPR_STATE_DIR`/`serve.log`) that keeps the model
loaded, so a stop typically transcribes and pastes in a few seconds. The
daemon idles out after 15 minutes; when it is not running the clip is decoded
in-process as before.
The last working microphone source is cached, avoiding a
recording probe on every activation. State and learned corrections can be
relocated with `WHISPR_STATE_DIR` and `WHISPR_DATA_DIR`.
`ydotoold` is optional; `wtype` is used as a fallback. WhisprFlow pastes through
the clipboard so Unicode text, including Polish characters, is preserved. The
transcript remains in the clipboard if the paste shortcut fails. Spark
correction runs automatically before the review window in its compact,
low-latency `whisprflow` context and never falls back to another Codex model.
This context recognizes explicit list and snippet cues such as `WhisprFlow,
lista`, `punkt pierwszy`, `A ... B ... C`, `snippet` and `blok kodu`. Without a
formatting cue, dictated prose remains prose. Set `WHISPER_SPARK_CORRECTION=0`
to keep the raw local transcript.
