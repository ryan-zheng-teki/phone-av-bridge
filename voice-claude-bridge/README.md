# Voice Claude Bridge

A CLI tool that allows you to interact with Claude using your voice. It wraps a Claude CLI command in a PTY, captures your audio, transcribes it using `faster-whisper`, and injects the text directly into the Claude prompt.

## Features

- **Voice Input:** Use a hotkey to toggle recording.
- **Local STT:** Uses `faster-whisper` for fast, local speech-to-text.
- **PTY Wrapper:** Wraps any Claude CLI command (default: `claude`).
- **Terminal Sync:** Synchronizes terminal window size with the wrapped process.
- **Cross-Platform:** Supports Linux (PulseAudio) and macOS (AVFoundation).

## Prerequisites

- **Python:** 3.9 - 3.13.
- **Audio Capture:**
  - **Linux:** `pulseaudio-utils` (for `parec` and `pactl`).
  - **macOS:** `ffmpeg` (installed via Homebrew).
- **Claude CLI:** A Claude CLI tool installed and available in your PATH.

## Installation

1.  Clone the repository.
2.  Navigate to the `voice-claude-bridge` directory.
3.  Run the installation script:
    ```bash
    ./install.sh
    ```
    This will create a symlink to `voice-claude` in `~/.local/bin`.

## Usage

Run the bridge by calling `voice-claude`:

```bash
voice-claude
```

You can pass extra arguments to the Claude command:

```bash
voice-claude -- --model claude-3-opus-20240229
```

### Hotkeys

- **Default Toggle:** `Ctrl+K`
- **Other Options:** Configurable via environment variables or CLI flags (e.g., `--record-key f8`).

## Configuration

You can configure the bridge using environment variables or a `.voice-claude.env` file in the bridge directory.

| Variable | Description | Default |
| :--- | :--- | :--- |
| `CLAUDE_CMD` | Command to start Claude | `claude` |
| `VOICE_CLAUDE_RECORD_KEY` | Hotkey to toggle recording | `ctrl-k` |
| `STT_MODEL` | Whisper model to use | `tiny.en` |
| `STT_LANGUAGE` | Language for transcription | `en` |
| `STT_DEVICE` | Device for transcription (`cpu`, `cuda`, `auto`) | `cpu` |

## License

MIT
