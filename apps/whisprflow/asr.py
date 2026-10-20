import json
import os
import re
import shutil
import socket
import sys
import time
import wave
from datetime import datetime
from pathlib import Path

import numpy as np

_MODEL_CACHE = {}


def _get_model(model_name):
    if model_name not in _MODEL_CACHE:
        from faster_whisper import WhisperModel

        _MODEL_CACHE[model_name] = WhisperModel(
            model_name,
            device="cpu",
            compute_type="int8",
            cpu_threads=max(4, min(12, (os.cpu_count() or 4))),
        )
    return _MODEL_CACHE[model_name]


def load_audio(wav_path):
    audio = None
    try:
        with wave.open(str(wav_path), "rb") as wf:
            frames = wf.readframes(wf.getnframes())
            if frames:
                audio = np.frombuffer(frames, dtype=np.int16).astype(np.float32) / 32768.0
    except Exception:
        audio = None
    if audio is None or audio.size == 0:
        # Partial / in-flight WAVs may carry an unsettled RIFF header while the
        # recording is still growing; parse the data payload directly.
        audio = _load_audio_unsettled(Path(wav_path))
    return audio


def _load_audio_unsettled(wav_path):
    try:
        data = wav_path.read_bytes()
    except OSError:
        return np.empty(0, dtype=np.float32)
    index = 0
    payload = b""
    while index + 8 <= len(data):
        if index == 0:
            if data[:4] != b"RIFF":
                break
            index = 12
            continue
        chunk_id = data[index : index + 4]
        chunk_size = int.from_bytes(data[index + 4 : index + 8], "little")
        start = index + 8
        if chunk_id == b"data":
            payload = data[start:] if chunk_size > len(data) - start else data[start : start + chunk_size]
            break
        step = chunk_size + (chunk_size & 1)
        if step <= 0:
            break
        index = start + step
    if not payload:
        return np.empty(0, dtype=np.float32)
    return np.frombuffer(payload, dtype=np.int16).astype(np.float32) / 32768.0


def transcribe_file(wav_path):
    wav_path = Path(wav_path)
    txt_path = Path(os.environ["TXT_PATH"]) if os.environ.get("TXT_PATH") else None
    dict_path = Path(os.environ["DICT_PATH"]) if os.environ.get("DICT_PATH") else None
    corrections_path = Path(os.environ["CORRECTIONS_PATH"]) if os.environ.get("CORRECTIONS_PATH") else None
    log_path = Path(os.environ["WHISPER_LOG_PATH"]) if os.environ.get("WHISPER_LOG_PATH") else None
    failed_dir = Path(os.environ["WHISPER_FAILED_DIR"]) if os.environ.get("WHISPER_FAILED_DIR") else None
    model_name = os.environ.get("WHISPER_MODEL", "large-v3-turbo")
    beam_size = int(os.environ.get("WHISPER_BEAM_SIZE", "5"))
    dual_raw = os.environ.get("WHISPER_DUAL", "1").strip().lower()
    dual_mode = {
        "0": "single",
        "false": "single",
        "no": "single",
        "2": "always",
        "always": "always",
    }.get(dual_raw, "conditional")
    min_score = float(os.environ.get("WHISPER_MIN_SCORE", "-0.47"))
    language = os.environ.get("WHISPER_LANGUAGE", "").strip() or None
    allowed_languages = [
        lang.strip()
        for lang in os.environ.get("WHISPER_LANGS", "pl,en").split(",")
        if lang.strip()
    ] or ["pl", "en"]
    vad_enabled = os.environ.get("WHISPER_VAD", "1").strip().lower() not in {"0", "false", "no"}

    def finish(text):
        if txt_path:
            try:
                txt_path.parent.mkdir(parents=True, exist_ok=True)
                txt_path.write_text(text, encoding="utf-8")
            except OSError:
                pass
        return text

    audio = load_audio(wav_path)
    if audio.size == 0:
        return finish("")

    tail_seconds = float(os.environ.get("WHISPER_TAIL_SECONDS", "0") or 0)
    if tail_seconds > 0:
        audio = audio[-int(tail_seconds * 16000) :]

    audio -= audio.mean()

    # Bring whisper-level input up to a normal speaking loudness. The decoder's
    # mel extractor normalizes per clip, so the boost mainly matters for the
    # voice activity detector, which needs a real amplitude to mark the speech.
    peak = float(np.max(np.abs(audio)))
    rms = float(np.sqrt(np.mean(audio.astype(np.float64) ** 2)))
    gain = 1.0
    if rms > 1e-6:
        gain = min(0.09 / rms, 64.0)
    gain = min(gain, 0.97 / max(peak, 1e-6))
    if gain > 1.0:
        audio = audio * gain
        peak *= gain

    # Close-range plosives can still hit the PCM ceiling; soft-limit those
    # peaks instead of feeding hard-clipped samples to the mel extractor.
    if peak > 0.985:
        audio = np.tanh(audio / 0.95) * 0.95

    duration_s = audio.size / 16000.0
    print(
        f"whisprflow: duration={duration_s:.2f}s rms={rms:.5f} peak={peak:.4f} gain={gain:.2f} model={model_name}",
        file=sys.stderr,
        flush=True,
    )

    initial_prompt = None
    if dict_path and dict_path.exists():
        lines = [ln.strip() for ln in dict_path.read_text(encoding="utf-8").splitlines() if ln.strip()]
        if lines:
            prompt = "Spellings: " + ", ".join(lines)
            initial_prompt = prompt[:1000]

    if corrections_path and corrections_path.exists():
        learned = []
        for line in corrections_path.read_text(encoding="utf-8").splitlines():
            if "\t" not in line:
                continue
            _wrong, correct = line.split("\t", 1)
            correct = correct.strip()
            if correct:
                learned.append(correct)
        if learned:
            learned_prompt = "Preferred terms: " + ", ".join(learned[:50])
            if initial_prompt:
                initial_prompt = f"{initial_prompt}. {learned_prompt}"[:1000]
            else:
                initial_prompt = learned_prompt[:1000]

    if allowed_languages and dual_mode == "single" and not language:
        prefix = f"Language: {', '.join(allowed_languages)}. "
        if initial_prompt:
            initial_prompt = (prefix + initial_prompt)[:1000]
        else:
            initial_prompt = prefix[:1000]

    model = _get_model(model_name)

    # Quiet close-range dictation sits low on the VAD detector; use a very soft
    # threshold and keep short pauses from splitting words. WHISPER_VAD=0 skips
    # the detector entirely and lets the decoder decide what is speech.
    vad_parameters = dict(
        threshold=0.25,
        min_speech_duration_ms=80,
        min_silence_duration_ms=800,
        speech_pad_ms=250,
    )

    def score_text(raw_text, base_score):
        if base_score is None or base_score != base_score:
            return -float("inf")
        score = base_score
        if raw_text:
            stripped = raw_text.replace(" ", "")
            if len(stripped) >= 8 and stripped[: len(stripped) // 2] == stripped[len(stripped) // 2 :]:
                score -= 1.0
            words = raw_text.lower().split()
            if len(words) >= 6 and len(set(words)) <= len(words) / 3:
                score -= 1.0
        return score

    def decode(lang):
        segments, info = model.transcribe(
            audio,
            language=lang,
            beam_size=beam_size,
            best_of=1,
            initial_prompt=initial_prompt,
            # Accept quieter, lower-confidence speech than the defaults.
            no_speech_threshold=0.85,
            log_prob_threshold=-1.6,
            vad_filter=vad_enabled,
            vad_parameters=vad_parameters,
            condition_on_previous_text=False,
        )
        segment_list = list(segments)
        raw_text = "".join(segment.text for segment in segment_list).strip()
        base_score = None
        if segment_list:
            spans = [max(0.0, segment.end - segment.start) for segment in segment_list]
            spoken = sum(spans)
            if spoken > 0:
                base_score = sum(
                    segment.avg_logprob * span for segment, span in zip(segment_list, spans)
                ) / spoken
            else:
                base_score = segment_list[0].avg_logprob
        return raw_text, score_text(raw_text, base_score)

    def format_score(score):
        return f"{score:.3f}" if score is not None else "none"

    def compact_text(raw_text, max_len=120):
        joined = " ".join(raw_text.split())
        return joined if len(joined) <= max_len else joined[: max_len - 1] + "…"

    attempt_log = []

    def run_decode(lang):
        started = time.time()
        outcome = decode(lang)
        attempt_log.append(
            {
                "lang": lang or "auto",
                "score": None if outcome[1] == -float("inf") else round(outcome[1], 3),
                "elapsedS": round(time.time() - started, 2),
                "text": compact_text(outcome[0]),
            }
        )
        return outcome

    if language:
        attempts = [run_decode(language)]
        text, _ = attempts[0]
    elif dual_mode == "single" or len(allowed_languages) < 2:
        attempts = [run_decode(None)]
        text, _ = attempts[0]
    else:
        # Forced-decode pl/en: run the primary language first; only pay a
        # second inference pass when confidence is too low to trust it,
        # keeping results always exactly PL or EN.
        attempts = [run_decode(allowed_languages[0])]
        if (
            dual_mode == "always"
            or attempts[0][0] == ""
            or attempts[0][1] is None
            or attempts[0][1] < min_score
        ):
            attempts.append(run_decode(allowed_languages[1]))
        text, _ = max(attempts, key=lambda attempt: (attempt[0] != "", attempt[1]))

    stamped = datetime.now().strftime("%Y%m%d-%H%M%S")
    try:
        if text:
            stats_path = os.environ.get("WHISPER_STATS_PATH")
            if stats_path:
                stats_file = Path(stats_path)
                stats_file.parent.mkdir(parents=True, exist_ok=True)
                with stats_file.open("a", encoding="utf-8") as fh:
                    fh.write(
                        json.dumps(
                            {
                                "t": stamped,
                                "durationS": round(duration_s, 2),
                                "words": len(text.split()),
                                "chars": len(text),
                            }
                        )
                        + "\n"
                    )
        if log_path:
            log_path.parent.mkdir(parents=True, exist_ok=True)
            with log_path.open("a", encoding="utf-8") as fh:
                fh.write(
                    f"{stamped} duration={duration_s:.2f}s rms={rms:.5f} gain={gain:.2f} "
                    f"model={model_name} beam={beam_size} vad={vad_enabled}\n"
                    + json.dumps(attempt_log, ensure_ascii=False)
                    + f"\nfinal='{compact_text(text)}'\n\n"
                )
        if not text and failed_dir:
            failed_dir.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(wav_path, failed_dir / f"{stamped}.wav")
    except Exception:
        pass

    if not text:
        return finish("")

    def normalize(raw):
        raw = re.sub(r"\b(laugh|laughs|laughing|laughter)\b", "haha", raw, flags=re.IGNORECASE)
        raw = re.sub(r"\b(uh|um|erm|er|ah|oh|hmm|hm|uhm|yyy|eee)\b", "", raw, flags=re.IGNORECASE)
        raw = re.sub(r"\s+", " ", raw).strip()
        raw = re.sub(r"\s+([,.;:!?])", r"\1", raw)
        return raw

    def apply_redo(txt):
        redo = False
        match = re.search(
            r"\b(no\s+){2,}(?:actually\s+|i mean\s+|i'm\s+|rather\s+|wait\s+|make that\s+|use\s+)?(?P<rest>.+)$",
            txt,
            flags=re.IGNORECASE,
        )
        if match and match.group("rest").strip():
            return match.group("rest").strip(), True
        match = re.search(
            r"\b(nie\s+){2,}(?:właściwie\s+|to\s+znaczy\s+|w\s+sen\s*?sie\s+|raczej\s+|czekaj\s+|poczekaj\s+|użyj\s+)?(?P<rest>.+)$",
            txt,
            flags=re.IGNORECASE,
        )
        if match and match.group("rest").strip():
            return match.group("rest").strip(), True

        markers = [
            r"\bscratch that\b",
            r"\bforget that\b",
            r"\bnever mind\b",
            r"\bnevermind\b",
            r"\bno wait\b",
            r"\bactually\b",
            r"\bi mean\b",
            r"\bmake that\b",
            r"\bcorrection\b",
            r"\bzapomnij( o tym)?\b",
            r"\bnieważne\b",
            r"\bto znaczy\b",
            r"\bw sensie\b",
            r"\bpoprawka\b",
            r"\bwłaściwie\b",
            r"\bczekaj\b",
            r"\bpoczekaj\b",
        ]
        last = None
        for pat in markers:
            for match in re.finditer(pat, txt, flags=re.IGNORECASE):
                last = match
        if last:
            rest = txt[last.end() :].strip(" ,")
            if rest:
                return rest, True
        return txt, redo

    def wrap_with(part, left, right):
        return f"{left}{part}{right}"

    text = normalize(text)
    text, redo_applied = apply_redo(text)

    structure_applied = False

    # Order matters: a code-block cue claims everything after it, so it runs
    # before the other cues. Spark handles these cues too; this is the local
    # fallback for when the LLM pass is disabled or unavailable.
    code_match = re.search(
        r"(?<![\w\u0301])(?P<cue>blok kodu|code block|snippet)(?:\s+(?P<lang>[a-z0-9+#-]+))?(?![\w\u0301])",
        text,
        flags=re.IGNORECASE,
    )
    if code_match:
        language = code_match.group("lang") or ""
        remainder = text[code_match.end() :].strip() if code_match.start() == 0 else None
        if remainder is None or not remainder:
            remainder = (text[: code_match.start()] + " " + text[code_match.end() :]).strip(" ,.:;")
        text = "```" + language + ("\n" + remainder + "\n" if remainder else "") + "```"
        structure_applied = True

    paragraph_cue = r"(?<![\w\u0301])(nowy\s+akapit|new\s+paragraph|akapit)(?![\w\u0301])"
    if re.search(paragraph_cue, text, flags=re.IGNORECASE):
        text = re.sub(paragraph_cue, "\n\n", text, flags=re.IGNORECASE)
        structure_applied = True

    newline_cue = r"(?<![\w\u0301])(nowa\s+linia|new\s+line)(?![\w\u0301])"
    if re.search(newline_cue, text, flags=re.IGNORECASE):
        text = re.sub(newline_cue, "\n", text, flags=re.IGNORECASE)
        structure_applied = True

    pl_ordinals = {
        "pierwszy": 1, "drugi": 2, "trzeci": 3, "czwarty": 4, "piąty": 5,
        "piaty": 5, "szósty": 6, "szosty": 6, "siódmy": 7, "siodmy": 7,
        "ósmy": 8, "osmy": 8, "dziewiąty": 9, "dziewiaty": 9, "dziesiąty": 10,
        "dziesiaty": 10,
    }
    pl_ordinals.update({str(number): number for number in list(pl_ordinals.values())})
    point_pattern = re.compile(
        r"(?<![\w\u0301])(?:punkt\s+|point\s+)(?P<ord>[a-ząćęłńóśźż]{4,20}|\d+)(?![\w\u0301])",
        re.IGNORECASE,
    )

    def render_point(match):
        token = match.group("ord").lower()
        number = pl_ordinals.get(token)
        if number is None:
            return match.group(0)
        return f"\n{number}. "

    if re.search(r"(?<![\w\u0301])(?:punkt|point)(?![\w\u0301])", text, flags=re.IGNORECASE):
        numbered = point_pattern.sub(render_point, text)
        if numbered != text:
            text = numbered
            structure_applied = True

    list_match = re.search(
        r"(?<![\w\u0301])(?:whisprflow\s*,?\s*)?lista\s*:?\s*(?P<rest>.+)$",
        text,
        flags=re.IGNORECASE,
    )
    if list_match:
        rest = list_match.group("rest").strip(" .,:;")
        items = [item.strip() for item in re.split(r"[,;]|\.{3}", rest) if item.strip()]
        if len(items) >= 2:
            text = text[: list_match.start()] + "\n" + "\n".join(f"- {item}" for item in items)
            structure_applied = True

    if structure_applied:
        text = re.sub(r"[ \t]+\n", "\n", text)
        text = re.sub(r"\s*\n\s*\n\s*", "\n\n", text.strip())
        text = re.sub(r"[ \t]+", " ", text)
        text = re.sub(r"^\s+", "", text, flags=re.MULTILINE)

    wrap_applied = False
    wrap_patterns = [
        ("()", ("(", ")"), ["parenthesis", "parentheses", "parens", "nawias", "nawiasy", "nawiasie", "nawiasach"]),
        (
            "[]",
            ("[", "]"),
            [
                "brackets",
                "square brackets",
                "nawiasy kwadratowe",
                "nawiasach kwadratowych",
                "nawias kwadratowy",
            ],
        ),
        ("{}", ("{", "}"), ["braces", "curly braces", "klamry", "klamrach", "nawiasy klamrowe", "klamra"]),
        (
            "\"\"",
            ("\"", "\""),
            [
                "double quotes",
                "quotes",
                "cudzyslow",
                "cudzyslowy",
                "cudzysłów",
                "cudzysłowie",
                "cudzysłowach",
            ],
        ),
        ("''", ("'", "'"), ["single quotes", "apostrophes", "apostrof", "apostrofy", "apostrofach"]),
    ]

    for _label, (left, right), cue_words in wrap_patterns:
        word_re = "|".join(re.escape(w) for w in cue_words)
        match = re.search(
            rf"\b(put|wstaw|daj|umieść|umiesc|wrzuć|wrzuc)\s+(.*?)\s+(in|w)\s+({word_re})\b",
            text,
            flags=re.IGNORECASE,
        )
        if match and match.group(1).strip():
            text = wrap_with(match.group(2).strip(), left, right)
            wrap_applied = True
            break

        match = re.search(rf"\b(in\s*side|inside|in|w)\s*({word_re})\b", text, flags=re.IGNORECASE)
        if match:
            text = (text[: match.start()] + text[match.end() :]).strip(" ,")
            text = wrap_with(text, left, right) if text else wrap_with("", left, right)
            wrap_applied = True
            break

    if redo_applied or wrap_applied:
        text = re.sub(r"^\s*use\s+(the\s+)?", "", text, flags=re.IGNORECASE).strip()

    if corrections_path and corrections_path.exists():
        entries = []
        for line in corrections_path.read_text(encoding="utf-8").splitlines():
            if "\t" not in line:
                continue
            wrong, correct = line.split("\t", 1)
            wrong = wrong.strip()
            correct = correct.strip()
            if wrong and correct:
                entries.append((wrong, correct))

        entries.sort(key=lambda item: (-len(item[0].split()), item[0].casefold()))
        for wrong, correct in entries:
            text = re.sub(rf"(?<!\w){re.escape(wrong)}(?!\w)", correct, text, flags=re.IGNORECASE)

    if dict_path and dict_path.exists():
        preferred_terms = [ln.strip() for ln in dict_path.read_text(encoding="utf-8").splitlines() if ln.strip()]
        preferred_terms.sort(key=lambda item: (-len(item.split()), item.casefold()))
        for term in preferred_terms:
            text = re.sub(rf"(?<!\w){re.escape(term)}(?!\w)", term, text, flags=re.IGNORECASE)

    return finish(text.strip())


def serve():
    sock_path = os.environ.get("WHISPR_SERVE_SOCK", "")
    if not sock_path:
        raise SystemExit("WHISPR_SERVE_SOCK missing")
    idle_seconds = float(os.environ.get("WHISPR_SERVE_IDLE", "900"))

    lock_path = sock_path + ".lock"
    import fcntl

    lock_fh = open(lock_path, "w")
    try:
        fcntl.flock(lock_fh, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        print("whisprflow-serve: already running", file=sys.stderr, flush=True)
        return 0

    print("whisprflow-serve: warming model...", file=sys.stderr, flush=True)
    warm_started = time.time()
    _get_model(os.environ.get("WHISPER_MODEL", "large-v3-turbo"))
    print(f"whisprflow-serve: ready in {time.time() - warm_started:.1f}s", file=sys.stderr, flush=True)

    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        os.unlink(sock_path)
    except FileNotFoundError:
        pass
    server.bind(sock_path)
    server.listen(2)
    server.settimeout(0.5)
    print(f"whisprflow-serve: listening on {sock_path}", file=sys.stderr, flush=True)

    idle_deadline = time.time() + idle_seconds
    try:
        while time.time() < idle_deadline:
            try:
                client, _addr = server.accept()
            except socket.timeout:
                continue
            client.settimeout(10)
            inbox = b""
            try:
                while not inbox.endswith(b"\n"):
                    chunk = client.recv(65536)
                    if not chunk:
                        break
                    inbox += chunk
                if inbox.strip():
                    request = json.loads(inbox.decode("utf-8"))
                    client.settimeout(600)
                    os.environ.update(request.get("env", {}))
                    transcribed = transcribe_file(request["wav"])
                    reply = json.dumps({"text": transcribed}, ensure_ascii=False)
                    client.sendall((reply + "\n").encode("utf-8"))
            except Exception as exc:
                try:
                    message = f"whisprflow-serve: request failed: {exc!r}"
                    client.sendall((json.dumps({"error": message}) + "\n").encode("utf-8"))
                except Exception:
                    pass
            finally:
                try:
                    client.close()
                except Exception:
                    pass
            idle_deadline = time.time() + idle_seconds
    finally:
        try:
            os.unlink(sock_path)
        except FileNotFoundError:
            pass
        print("whisprflow-serve: idle shutdown", file=sys.stderr, flush=True)
    return 0


if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else "serve"
    if command == "serve":
        raise SystemExit(serve())
    print("usage: asr.py serve", file=sys.stderr)
    raise SystemExit(2)
