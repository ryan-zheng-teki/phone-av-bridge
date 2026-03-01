# Investigation Notes - Voice Claude Bridge

## Entry Points and Boundaries
- Entry point: `voice-claude` bash script.
- Execution boundary: PTY wrapping a target command (e.g., `claude`).
- Audio boundary: `audio_capture.py` interacting with `parec` (Linux) or `ffmpeg` (macOS).
- Transcription boundary: `faster-whisper` library.

## Key Findings
- Both `voice-codex` and `voice-gemini` bridges share ~95% of the same code.
- `voice-gemini` includes terminal window size synchronization which is an improvement over `voice-codex`.
- The logic is highly modular, split between `cli.py` (orchestration) and `audio_capture.py` (hardware interaction).
- Dependencies are minimal: `faster-whisper` and `requests`.

## Constraints
- Must support Linux and macOS.
- Must work with Python 3.9-3.13.

## Naming Conventions
- Folder: `voice-claude-bridge`
- Wrapper: `voice-claude`
- CLI class: `VoiceClaudeCliBridge`
- Env variables: `VOICE_CLAUDE_*`

## Scope Triage
- Triage: `Small`
- Rationale: This is a pattern-match implementation of existing stable logic. It involves creating one new folder with 4-5 files that are mostly copies of existing ones with name substitutions and one minor enhancement (winsize sync).

## Questions/Unknowns
- Is there an official or common `claude` CLI tool the user expects to bridge?
- Preferred default hotkey? `Ctrl-G` for Gemini, `Ctrl-X` for Codex. Maybe `Ctrl-A` for Anthropic/Claude? Or `Ctrl-B`? I'll check what's available. `Ctrl-C` is taken. `Ctrl-D` is EOF. `Ctrl-Z` is suspend.
- Let's look at `cli.py` hotkeys again.
  - Codex: `ctrl-x` (0x18)
  - Gemini: `ctrl-g` (0x07)
- Maybe `ctrl-q` or `ctrl-k`?
- I'll propose `ctrl-s` or something distinct. Actually, `ctrl-g` for Gemini (Google), `ctrl-x` for Codex. Maybe `ctrl-l` for Claude (L)? No, `ctrl-l` is usually clear screen.
- Let's use `ctrl-j` or something. I'll ask or just pick a reasonable default. `ctrl-g` is 0x07. `ctrl-x` is 0x18.
- Let's use `ctrl-b` (0x02) maybe? Or `ctrl-k` (0x0B).
