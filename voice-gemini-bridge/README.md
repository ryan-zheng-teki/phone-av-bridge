# Voice to Gemini PTY Bridge (CLI)

Local app that records microphone audio, transcribes it with a small local STT model, and sends text to a Gemini process via PTY stdin.

## Why PTY

This app launches Gemini in its own PTY so text injection is deterministic (much more reliable than trying to inject into an arbitrary existing terminal).

## Hotkeys

- `Ctrl+G`: start/stop recording (default).
- On stop, transcript is appended to the current Gemini input line. Press Enter in Gemini to submit the full composed message.

All other keys are forwarded to Gemini unchanged.

## Quick start

```bash
cd voice-gemini-bridge
./install.sh
./voice-gemini -h
```

`voice-gemini` auto-creates `./.venv` and installs missing Python dependencies on first run.

Platform recording dependencies:
- Linux/WSL: `pactl` + `parec` (`pulseaudio-utils`).
- macOS: `ffmpeg` (`brew install ffmpeg`).

## Environment variables

- `STT_MODEL` default: `tiny.en`
- `STT_LANGUAGE` default: `en`
- `STT_DEVICE` default: `cpu`
- `STT_COMPUTE_TYPE` default: `int8`
- `GEMINI_CMD` default: `gemini`
- `VOICE_GEMINI_RECORD_KEY` default: `ctrl-g`

## Customization

You can pass normal Gemini flags directly:

```bash
./voice-gemini --model gemini-2.0-flash
./voice-gemini --yolo
```

To change the recording key:

```bash
./voice-gemini --record-key f8
```
