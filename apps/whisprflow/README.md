# WhisprFlow CLI

Local push-to-talk dictation for Wayland. It records from PipeWire, transcribes
locally with `faster-whisper`, lets you correct the text, learns correction
pairs, improves Polish and English with GPT-5.3-Codex-Spark, applies explicitly
spoken formatting and types the result into the previously focused field.

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

The default model is `large-v3-turbo` (downloaded from Hugging Face on first
use). Set `WHISPER_MODEL` to use another faster-whisper model (use `small` on
slower machines; `large-v3-turbo` is CPU-heavy but much more accurate on quiet
speech). By default the
clip is decoded twice — once forced to Polish, once to English — and the more
confident hypothesis wins, so the result is always one of the two languages
(`WHISPER_DUAL=0` disables this and falls back to automatic language
detection in a single pass). Force a language with `WHISPER_LANGUAGE`, adjust
the search with `WHISPER_BEAM_SIZE` (default `5`), set `WHISPER_DUAL`, or
override `WHISPER_MODEL`, `WHISPER_LANGS` and `WHISPER_SOURCE`. Quiet close-range dictation is recognized too: the clip is auto-gained to a
normal speaking level before decoding, the VAD threshold is relaxed
(`WHISPER_VAD=0` skips the detector entirely and lets the decoder decide what
is speech), borderline-silent segments are accepted more readily, and clipped
peaks are soft-limited — so holding the mic 2–3 cm from your mouth and
whispering works. The last working microphone source is cached, avoiding a
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
