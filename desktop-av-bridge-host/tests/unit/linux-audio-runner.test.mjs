import test from 'node:test';
import assert from 'node:assert/strict';
import { LinuxAudioRunner } from '../../adapters/linux-audio/audio-runner.mjs';

test('linux audio runner uses phone-identifiable microphone selection target', () => {
  const runner = new LinuxAudioRunner({ enableSpeaker: true });
  runner.setDeviceIdentity({
    deviceName: 'Pixel 9 Pro',
    deviceId: 'android-49695fb08f153049',
  });

  const label = runner.getMicrophoneDeviceName();
  assert.match(label, /^Pixel 9 Pro Microphone/);
  assert.match(label, /Monitor of PhoneAVBridgeMic-pixel-9-pro-153049/);
});
