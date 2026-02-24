# Investigation Notes - Voice Codex macOS Intel Support

## Task
Enable `voice-codex-bridge` to work on this machine (Intel macOS 13), while preserving Linux/WSL behavior and enforcing separation of concerns.

## Sources Consulted

### Local repository
- `voice-codex-bridge/README.md`
- `voice-codex-bridge/install.sh`
- `voice-codex-bridge/voice-codex`
- `voice-codex-bridge/cli.py`
- `voice-codex-bridge/requirements.txt`
- `voice-codex-bridge/tests/test_cli_helpers.py`
- `AGENTS.md`

### Local runtime evidence (commands)
- `uname -m` -> `x86_64`
- `sw_vers` -> macOS `13.7.8`
- `python3 --version` -> `3.14.3`
- `./voice-codex -h` in `voice-codex-bridge` failed dependency install: `No matching distribution found for onnxruntime<2,>=1.14`
- Python 3.11 isolated install test for `requirements.txt` succeeded (includes `onnxruntime`, `faster-whisper` wheels on macOS x86_64)
- `command -v pactl` and `command -v parec` returned not found
- `python cli.py --command 'codex --version'` under a Python 3.11 venv failed with `parec not found in PATH`

## Key Findings
1. Current installer/wrapper assumes `python3` in PATH; on this machine that is Python 3.14 and fails for current STT dependency stack.
2. Current runtime recording path is Linux PulseAudio-specific (`parec` + `pactl`), hard-coded in `cli.py`.
3. Intel architecture is not the blocker; dependency/runtime tooling selection is the blocker.
4. macOS path can be implemented via a dedicated recorder backend (e.g., `ffmpeg` avfoundation), keeping PTY/STT logic untouched.
5. Existing tests are helper-focused and currently coupled to Pulse command-building behavior.

## Constraints and Implications
- Must preserve Linux/WSL behavior already working for user.
- Must avoid backward-compat shim sprawl; cleanly separate recorder concerns by platform.
- Must keep CLI UX stable (`--record-source` flag remains usable).
- macOS voice capture dependency should be explicit and install guidance should be accurate.

## Open Unknowns
- Exact macOS microphone device naming/index across different setups (built-in mic, headset, aggregate device).
- Whether ffmpeg is preinstalled on user machines by default (typically no).

## Implications for Design
- Introduce recorder backend abstraction boundary.
- Move OS-specific command construction + source discovery out of bridge orchestration path.
- Make Python interpreter selection explicit in install/launcher scripts to avoid unsupported default Python versions.
- Add tests for backend-selection and command construction for both Linux and macOS.
