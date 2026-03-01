# Future-State Runtime Call Stack - Voice Gemini CLI Tool

## UC-001: Hotkey Toggle (Start Recording)
- **Use Case ID:** UC-001
- **Source:** Requirement
- **Description:** User presses `Ctrl+G` to start recording.

```text
voice-gemini-bridge/cli.py:main()
  -> VoiceGeminiCliBridge.run()
    -> select.select([stdin, master_fd])
    -> VoiceGeminiCliBridge._handle_stdin_bytes()
      -> record_key_sequence_matches(0x07, "ctrl-g") -> returns 1
      -> VoiceGeminiCliBridge._toggle_recording()
        -> VoiceGeminiCliBridge._start_recording()
          -> AudioCaptureBackend.resolve_source(...)
          -> AudioCaptureBackend.build_record_command(...)
          -> subprocess.Popen(["parec", ...])
          -> VoiceGeminiCliBridge._print_status("recording started...")
```

## UC-001: Hotkey Toggle (Stop Recording)
- **Use Case ID:** UC-001
- **Source:** Requirement
- **Description:** User presses `Ctrl+G` to stop recording.

```text
voice-gemini-bridge/cli.py:main()
  -> VoiceGeminiCliBridge.run()
    -> select.select([stdin, master_fd])
    -> VoiceGeminiCliBridge._handle_stdin_bytes()
      -> record_key_sequence_matches(0x07, "ctrl-g") -> returns 1
      -> VoiceGeminiCliBridge._toggle_recording()
        -> VoiceGeminiCliBridge._stop_recording()
          -> process.send_signal(signal.SIGTERM)
          -> process.wait()
          -> VoiceGeminiCliBridge._convert_raw_to_wav(...)
          -> VoiceGeminiCliBridge._transcribe_and_maybe_send(...)
            -> SttEngine.transcribe_file(...)
              -> faster_whisper.WhisperModel.transcribe(...)
            -> os.write(self._master_fd, transcribed_text)
            -> VoiceGeminiCliBridge._print_status("transcript updated.")
```

## UC-003: Gemini Input Injection
- **Use Case ID:** UC-003
- **Source:** Requirement
- **Description:** Transcribed text is injected into Gemini PTY.

```text
voice-gemini-bridge/cli.py:VoiceGeminiCliBridge._transcribe_and_maybe_send(wav_path)
  -> text = self.stt_engine.transcribe_file(wav_path)
  -> if self.auto_send and self._master_fd is not None:
    -> os.write(self._master_fd, (text + " ").encode("utf-8"))
    -> VoiceGeminiCliBridge._print_status("appended to gemini draft; press Enter to send.")
```

## UC-005: Transcription Error Handling
- **Use Case ID:** UC-005
- **Source:** Design-Risk
- **Description:** Handle failures in the STT engine gracefully.

```text
voice-gemini-bridge/cli.py:VoiceGeminiCliBridge._transcribe_and_maybe_send(wav_path)
  -> try:
    -> SttEngine.transcribe_file(wav_path)
      -> raises RuntimeError("Model load failed")
  -> except Exception as error:
    -> VoiceGeminiCliBridge._print_status(f"transcribe failed: {error}")
    -> os.remove(wav_path)
```
