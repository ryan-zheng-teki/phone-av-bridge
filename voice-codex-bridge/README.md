# Voice to Codex PTY Bridge (CLI)

Local app that records microphone audio, transcribes it with a small STT model, and sends text to a Codex process via PTY stdin.

## Why PTY

This app launches Codex in its own PTY so text injection is deterministic (much more reliable than trying to inject into an arbitrary existing terminal).

## Small model options (official references)

- OpenAI Whisper models: `tiny`, `base`, `small`, `medium`, `large`.
  - Source: https://github.com/openai/whisper
- faster-whisper (optimized Whisper inference; good CPU default for this MVP).
  - Source: https://github.com/SYSTRAN/faster-whisper
- whisper.cpp (quantized models, very light local runtime option).
  - Source: https://github.com/ggerganov/whisper.cpp
- Vosk offline models (very small footprints, lower quality for general dictation).
  - Source: https://alphacephei.com/vosk/models

Default in this MVP: `small` + `zh` (better Mandarin recognition with acceptable local latency).

## Quick start (CLI only)

```bash
cd voice-codex-bridge
./install.sh
./voice-codex -h
```

`voice-codex` now auto-creates `./.venv` and installs missing Python dependencies on first run.
`./install.sh` also creates `./.voice-codex.env` on first run with defaults `STT_MODEL=small` and `STT_LANGUAGE=zh`.
Manual setup is still supported:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Terminal mode (CLI only)

Run Codex inside the wrapper PTY:

```bash
cd voice-codex-bridge
./voice-codex
```

Hotkeys:
- `Ctrl+X`: start/stop recording (default)
- On stop, transcript is appended to the current Codex input line. Press Enter in Codex to submit the full composed message.

All other keys are forwarded to Codex unchanged, so normal Codex commands still work.

You can pass normal Codex flags directly:

```bash
./voice-codex -h
./voice-codex resume
./voice-codex --model gpt-5 --approval never
```

If you want `voice-codex` in your `PATH`:

```bash
chmod +x voice-codex
mkdir -p ~/.local/bin
ln -sf \"$(pwd)/voice-codex\" ~/.local/bin/voice-codex
```

Then run:

```bash
voice-codex -h
```

Optional flags:
- `--no-auto-send` prints transcript without sending.
- `--record-key f8` or `--record-key f9` for easy non-typing hotkeys.
- `--record-key ctrl-x` (default) or `--record-key ctrl-r` for keyboard chord hotkeys.
- `--record-key enter` uses Enter as start/stop recording key.
- `--record-source <pulse-source>` selects non-default audio source.
- `--stt-model tiny|base|small|...` chooses STT model.

Forward full Codex startup args without changing your usual command style:

```bash
python3 cli.py --model gpt-5 --approval never
```

This runs `codex --model gpt-5 --approval never` inside the PTY bridge.

If you need wrapper STT settings plus Codex args:

```bash
python3 cli.py --stt-model base --stt-language zh --model gpt-5 --approval never
```

## Integration tests

```bash
cd voice-codex-bridge
python3 -m unittest discover -s tests -v
```

## Usage

1. Run `./voice-codex`.
2. Press the record key (default: `Ctrl+X`) to start/stop recording.
3. Speak, stop recording, then continue speaking and stop again to append more to the draft.
4. Press `Enter` in Codex once to send the composed prompt.

## Environment variables

- `STT_MODEL` default: `small`
- `STT_LANGUAGE` default: `zh`
- `LANG_CODE` optional compatibility alias for `STT_LANGUAGE` (for external configs).
- `STT_DEVICE` default: `cpu`
- `STT_COMPUTE_TYPE` default: `int8`
- `CODEX_CMD` default: `codex`
- `VOICE_CODEX_RECORD_SOURCE` optional: force Pulse source name used by CLI recorder.
- `VOICE_CODEX_RECORD_KEY` optional: `ctrl-x` (default), `ctrl-r`, `f8`, `f9`, or `enter`.

If `LANG_CODE`/`STT_LANGUAGE` is Chinese (`zh*`) and model is accidentally set to English-only (`*.en`), the CLI auto-switches to `small`.

## Notes

- PTY input still depends on Codex current terminal state; avoid nested interactive tools when dictating.
- First transcription call downloads model weights if not cached yet.

## CLI troubleshooting

- If you see `Invalid data found when processing input` repeatedly:
  - old CLI versions used ffmpeg Pulse input, which is unsupported on some ffmpeg builds.
  - use the updated CLI (now records with `parec` and writes WAV safely).
- If transcript stays empty:
  - run `pactl list short sources` and pick a source manually:
    - `python3 cli.py --record-source <source-name>`
