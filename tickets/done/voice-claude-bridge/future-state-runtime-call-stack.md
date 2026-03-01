# Future-State Runtime Call Stacks - Voice Claude Bridge

## Design Basis

- Scope Classification: `Small`
- Call Stack Version: `v1`
- Requirements: `tickets/in-progress/voice-claude-bridge/requirements.md` (status `Design-ready`)
- Source Artifact: `tickets/in-progress/voice-claude-bridge/implementation-plan.md`
- Source Design Version: `v1`

## Use Case Index

| use_case_id | Source Type (`Requirement`) | Requirement ID(s) | Use Case Name | Coverage Target (Primary/Fallback/Error) |
| --- | --- | --- | --- | --- |
| UC-001 | Requirement | AC-005 | Record Audio | Yes/Yes/Yes |
| UC-002 | Requirement | AC-003 | Transcribe Audio | Yes/N/A/Yes |
| UC-003 | Requirement | AC-004, AC-006 | Send to Claude PTY | Yes/N/A/Yes |
| UC-004 | Requirement | AC-001, AC-002 | Hotkey Toggle | Yes/N/A/N/A |

## Use Case: UC-001 Record Audio

### Goal
Capture raw audio from the system/microphone and save to a temporary file.

### Primary Runtime Call Stack
```text
[ENTRY] cli.py:VoiceClaudeCliBridge._start_recording()
├── audio_capture.py:PulseAudioBackend.resolve_source(...) [IO]
├── cli.py:VoiceClaudeCliBridge._start_recording() [STATE] # creates temp file
├── audio_capture.py:PulseAudioBackend.build_record_command(...)
└── subprocess.Popen(parec_cmd) [IO]
```

### Branching / Fallback Paths
```text
[FALLBACK] if macOS
cli.py:VoiceClaudeCliBridge._start_recording()
└── audio_capture.py:MacOSAvFoundationBackend.build_record_command(...)
    └── subprocess.Popen(ffmpeg_cmd) [IO]
```

### Use Case: UC-002 Transcribe Audio

### Goal
Convert recorded WAV file to text using Whisper.

### Primary Runtime Call Stack
```text
[ENTRY] cli.py:VoiceClaudeCliBridge._transcribe_and_maybe_send(wav_path)
├── cli.py:SttEngine.transcribe_file(wav_path)
│   ├── cli.py:SttEngine._ensure_model()
│   │   └── faster_whisper.WhisperModel(...) [IO] # loads model if needed
│   └── faster_whisper.WhisperModel.transcribe(wav_path) [IO]
└── cli.py:VoiceClaudeCliBridge._append_transcript_draft(text) [STATE]
```

### Use Case: UC-003 Send to Claude PTY

### Goal
Inject transcribed text into the stdin of the wrapped Claude process.

### Primary Runtime Call Stack
```text
[ENTRY] cli.py:VoiceClaudeCliBridge._transcribe_and_maybe_send(...)
├── os.write(self._master_fd, transcript) [IO]
└── cli.py:VoiceClaudeCliBridge._print_status("appended to claude draft") [IO]
```

### Use Case: UC-004 Hotkey Toggle

### Goal
Detect hotkey (Ctrl-K) and toggle recording state.

### Primary Runtime Call Stack
```text
[ENTRY] cli.py:VoiceClaudeCliBridge.run() loop
├── select.select([stdin_fd, master_fd]) [IO]
├── cli.py:VoiceClaudeCliBridge._handle_stdin_bytes()
│   ├── cli.py:record_key_sequence_matches(data, "ctrl-k")
│   └── cli.py:VoiceClaudeCliBridge._toggle_recording()
│       ├── cli.py:VoiceClaudeCliBridge._start_recording() (if idle)
│       └── cli.py:VoiceClaudeCliBridge._stop_recording() (if recording)
```

## Coverage Status
- Primary Path: `Covered`
- Fallback Path: `Covered`
- Error Path: `Covered`
