import test from 'node:test';
import assert from 'node:assert/strict';
import { LinuxAudioRunner, pickLinuxSpeakerCaptureSource } from '../../adapters/linux-audio/audio-runner.mjs';

test('linux audio runner uses phone-identifiable microphone selection target', () => {
  const runner = new LinuxAudioRunner({ enableSpeaker: true });
  runner.setDeviceIdentity({
    deviceName: 'Pixel 9 Pro',
    deviceId: 'android-49695fb08f153049',
  });

  const label = runner.getMicrophoneDeviceName();
  assert.match(label, /^Pixel 9 Pro Microphone/);
  assert.match(label, /PhoneAVBridgeMicInput-pixel-9-pro-153049/);
});

test('speaker source resolver keeps safe default monitor', () => {
  const source = pickLinuxSpeakerCaptureSource({
    defaultSinkName: 'alsa_output.pci-0000_00_1f.3.analog-stereo',
    sources: [
      'alsa_output.pci-0000_00_1f.3.analog-stereo.monitor',
      'alsa_input.usb-device.mono-fallback',
    ],
    micSinkName: 'phone_av_bridge_mic_sink_pixel_9_pro_153049',
    micSourceName: 'phone_av_bridge_mic_src_pixel_9_pro_153049',
  });
  assert.equal(source, 'alsa_output.pci-0000_00_1f.3.analog-stereo.monitor');
});

test('speaker source resolver excludes bridge mic monitor when default sink points to mic sink', () => {
  const source = pickLinuxSpeakerCaptureSource({
    defaultSinkName: 'phone_av_bridge_mic_sink_pixel_9_pro_153049',
    sources: [
      'phone_av_bridge_mic_sink_pixel_9_pro_153049.monitor',
      'alsa_output.pci-0000_00_1f.3.analog-stereo.monitor',
      'alsa_input.usb-device.mono-fallback',
    ],
    micSinkName: 'phone_av_bridge_mic_sink_pixel_9_pro_153049',
    micSourceName: 'phone_av_bridge_mic_src_pixel_9_pro_153049',
  });
  assert.equal(source, 'alsa_output.pci-0000_00_1f.3.analog-stereo.monitor');
});

test('speaker source resolver returns null when only bridge microphone sources are available', () => {
  const source = pickLinuxSpeakerCaptureSource({
    defaultSinkName: 'phone_av_bridge_mic_sink_pixel_9_pro_153049',
    sources: [
      'phone_av_bridge_mic_sink_pixel_9_pro_153049.monitor',
      'phone_av_bridge_mic_src_pixel_9_pro_153049',
    ],
    micSinkName: 'phone_av_bridge_mic_sink_pixel_9_pro_153049',
    micSourceName: 'phone_av_bridge_mic_src_pixel_9_pro_153049',
  });
  assert.equal(source, null);
});

test('speaker source resolver keeps explicit override as highest priority', () => {
  const source = pickLinuxSpeakerCaptureSource({
    override: 'custom.route.monitor',
    defaultSinkName: 'phone_av_bridge_mic_sink_pixel_9_pro_153049',
    sources: ['phone_av_bridge_mic_sink_pixel_9_pro_153049.monitor'],
    micSinkName: 'phone_av_bridge_mic_sink_pixel_9_pro_153049',
    micSourceName: 'phone_av_bridge_mic_src_pixel_9_pro_153049',
  });
  assert.equal(source, 'custom.route.monitor');
});
