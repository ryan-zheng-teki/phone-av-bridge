# Future-State Runtime Call Stacks (Debug-Trace Style)

## Design Basis
- Scope Classification: `Medium`
- Call Stack Version: `v1`
- Requirements: `tickets/in-progress/voice-codex-macos-intel-support/requirements.md` (status `Design-ready`)
- Source Artifact: `tickets/in-progress/voice-codex-macos-intel-support/proposed-design.md`
- Source Design Version: `v1`
- Referenced Sections: Change Inventory C-001..C-006, File And Module Breakdown

## Use Case Index (Stable IDs)
| use_case_id | Requirement | Use Case Name | Coverage Target (Primary/Fallback/Error) |
| --- | --- | --- | --- |
| UC-001 | R-001 | Install on Intel macOS with compatible Python | Yes/N/A/Yes |
| UC-002 | R-002 | Start bridge on macOS and pass prereqs | Yes/Yes/Yes |
| UC-003 | R-002 | Record and transcribe on macOS | Yes/Yes/Yes |
| UC-004 | R-003, R-004 | Preserve Linux/WSL Pulse behavior | Yes/Yes/Yes |

## Transition Notes
- Migration replaces Linux-specific helper coupling in `cli.py` with backend calls from `audio_capture.py`.
- No temporary legacy dual path is kept; old direct helper paths are removed in implementation.

## Use Case: UC-001 [Install on Intel macOS with compatible Python]

### Primary Runtime Call Stack
```text
[ENTRY] voice-codex-bridge/install.sh:main
├── voice-codex-bridge/install.sh:select_python_command() [STATE]
├── voice-codex-bridge/install.sh:create_venv(python_cmd) [IO]
├── voice-codex-bridge/install.sh:install_requirements(venv_python) [IO]
├── voice-codex-bridge/install.sh:validate_imports(venv_python)
└── voice-codex-bridge/install.sh:link_voice_codex_binary() [IO]
```

### Branching / Fallback Paths
```text
[ERROR] if no supported Python found
voice-codex-bridge/install.sh:select_python_command()
└── voice-codex-bridge/install.sh:exit_with_guidance()
```

### Coverage Status
- Primary Path: `Covered`
- Fallback Path: `N/A`
- Error Path: `Covered`

## Use Case: UC-002 [Start bridge on macOS and pass prereqs]

### Primary Runtime Call Stack
```text
[ENTRY] voice-codex-bridge/voice-codex:main
├── voice-codex-bridge/voice-codex:select_python_command() [STATE]
├── voice-codex-bridge/voice-codex:ensure_python_deps(venv_python) [IO]
├── voice-codex-bridge/cli.py:main()
│   ├── voice-codex-bridge/audio_capture.py:select_audio_backend(platform=darwin)
│   ├── voice-codex-bridge/cli.py:VoiceCodexCliBridge.run()
│   │   ├── voice-codex-bridge/audio_capture.py:MacOSAvFoundationBackend.ensure_prereqs()
│   │   ├── voice-codex-bridge/cli.py:VoiceCodexCliBridge._start_codex() [ASYNC]
│   │   └── voice-codex-bridge/cli.py:VoiceCodexCliBridge._event_loop() [ASYNC]
```

### Branching / Fallback Paths
```text
[FALLBACK] if custom source is not provided
voice-codex-bridge/audio_capture.py:MacOSAvFoundationBackend.resolve_source(configured_source="")
└── returns backend default source (audio index)
```

```text
[ERROR] ffmpeg missing
voice-codex-bridge/audio_capture.py:MacOSAvFoundationBackend.ensure_prereqs()
└── raises RuntimeError("ffmpeg not found...")
```

### Coverage Status
- Primary Path: `Covered`
- Fallback Path: `Covered`
- Error Path: `Covered`

## Use Case: UC-003 [Record and transcribe on macOS]

### Primary Runtime Call Stack
```text
[ENTRY] voice-codex-bridge/cli.py:VoiceCodexCliBridge._toggle_recording()
├── voice-codex-bridge/cli.py:VoiceCodexCliBridge._start_recording()
│   ├── voice-codex-bridge/audio_capture.py:MacOSAvFoundationBackend.resolve_source(...)
│   ├── voice-codex-bridge/audio_capture.py:MacOSAvFoundationBackend.build_record_command(...) [STATE]
│   └── subprocess.Popen(ffmpeg...) [IO]
├── voice-codex-bridge/cli.py:VoiceCodexCliBridge._stop_recording() [ASYNC]
│   ├── terminate recorder process
│   ├── voice-codex-bridge/cli.py:VoiceCodexCliBridge._convert_raw_to_wav(...) [IO]
│   └── voice-codex-bridge/cli.py:VoiceCodexCliBridge._transcribe_and_maybe_send(...)
│       ├── voice-codex-bridge/cli.py:SttEngine.transcribe_file(...) [ASYNC]
│       └── write transcript to codex PTY [IO]
```

### Branching / Fallback Paths
```text
[FALLBACK] if probed source is not capturable
voice-codex-bridge/audio_capture.py:MacOSAvFoundationBackend.resolve_source(...)
└── returns default source
```

```text
[ERROR] STT engine failure
voice-codex-bridge/cli.py:VoiceCodexCliBridge._transcribe_and_maybe_send(...)
└── status update: transcribe failed
```

### Coverage Status
- Primary Path: `Covered`
- Fallback Path: `Covered`
- Error Path: `Covered`

## Use Case: UC-004 [Preserve Linux/WSL Pulse behavior]

### Primary Runtime Call Stack
```text
[ENTRY] voice-codex-bridge/cli.py:main()
├── voice-codex-bridge/audio_capture.py:select_audio_backend(platform=linux)
├── voice-codex-bridge/cli.py:VoiceCodexCliBridge.run()
│   ├── voice-codex-bridge/audio_capture.py:PulseAudioBackend.ensure_prereqs()
│   ├── voice-codex-bridge/cli.py:VoiceCodexCliBridge._start_recording()
│   │   └── voice-codex-bridge/audio_capture.py:PulseAudioBackend.build_record_command(...)
│   └── voice-codex-bridge/cli.py:VoiceCodexCliBridge._stop_recording() -> STT flow
```

### Branching / Fallback Paths
```text
[FALLBACK] if preferred Pulse source is invalid
voice-codex-bridge/audio_capture.py:PulseAudioBackend.resolve_source(...)
└── iterates sources and falls back to `default`
```

```text
[ERROR] Pulse prerequisites missing
voice-codex-bridge/audio_capture.py:PulseAudioBackend.ensure_prereqs()
└── raises RuntimeError with missing command detail
```

### Coverage Status
- Primary Path: `Covered`
- Fallback Path: `Covered`
- Error Path: `Covered`
