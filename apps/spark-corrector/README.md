# Spark Corrector

A small Wayland proofreader for Polish and English. It uses the locally signed-in
Codex CLI and always requests `gpt-5.3-codex-spark`. It never falls back to a
different model.

## Desktop use

Select text in any application and press `Super+G`. Review the corrected text
and its change list, then replace the selection or copy the result.

Commands:

- `spark-corrector selection` corrects the current selection.
- `spark-corrector clipboard` corrects text already in the clipboard.
- `spark-corrector filter --mode standard` reads text on stdin.
- `spark-corrector filter --mode transcript` additionally repairs likely speech
  recognition errors.
- `spark-corrector model` prints the fixed model identifier.

The filter command is used automatically by WhisprFlow before its review window.
Set `WHISPER_SPARK_CORRECTION=0` to disable that integration temporarily. A
failed or timed-out Spark request leaves the original transcript unchanged.

The Codex CLI must be authenticated with a ChatGPT account that has access to
GPT-5.3-Codex-Spark. The request timeout defaults to 120 seconds and can be
changed with `SPARK_CORRECTOR_TIMEOUT_SECONDS`.
