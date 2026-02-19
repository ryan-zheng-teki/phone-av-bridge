import test from 'node:test';
import assert from 'node:assert/strict';
import {
  buildLinuxMicFfmpegArgs,
  isLinuxMicLowLatencyEnabled,
  LinuxAudioRunner,
  pickLinuxSpeakerCaptureSource,
  resolveLinuxMicPulseLatencyMsec,
} from '../../adapters/linux-audio/audio-runner.mjs';

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

test('linux mic low latency mode is enabled by default and can be disabled explicitly', () => {
  assert.equal(isLinuxMicLowLatencyEnabled(undefined), true);
  assert.equal(isLinuxMicLowLatencyEnabled('0'), false);
  assert.equal(isLinuxMicLowLatencyEnabled('false'), false);
  assert.equal(isLinuxMicLowLatencyEnabled('off'), false);
  assert.equal(isLinuxMicLowLatencyEnabled('no'), false);
  assert.equal(isLinuxMicLowLatencyEnabled('1'), true);
});

test('linux mic pulse latency parser clamps invalid values and keeps valid values', () => {
  assert.equal(resolveLinuxMicPulseLatencyMsec(undefined), '30');
  assert.equal(resolveLinuxMicPulseLatencyMsec(''), '30');
  assert.equal(resolveLinuxMicPulseLatencyMsec('abc'), '30');
  assert.equal(resolveLinuxMicPulseLatencyMsec('2'), '30');
  assert.equal(resolveLinuxMicPulseLatencyMsec('800'), '30');
  assert.equal(resolveLinuxMicPulseLatencyMsec('25'), '25');
});

test('linux mic ffmpeg args include low latency flags by default', () => {
  const args = buildLinuxMicFfmpegArgs('rtsp://example.local:1935/', { lowLatency: true });
  assert.deepEqual(args.slice(0, 8), [
    '-hide_banner',
    '-loglevel',
    'warning',
    '-rtsp_transport',
    'tcp',
    '-fflags',
    'nobuffer',
    '-flags',
  ]);
  assert.ok(args.includes('low_delay'));
  assert.ok(args.includes('-analyzeduration'));
  assert.ok(args.includes('-probesize'));
  assert.ok(args.includes('-flush_packets'));
});

test('linux mic ffmpeg args can be built without low latency flags', () => {
  const args = buildLinuxMicFfmpegArgs('rtsp://example.local:1935/', { lowLatency: false, rtspTransport: 'udp' });
  assert.deepEqual(args.slice(0, 5), [
    '-hide_banner',
    '-loglevel',
    'warning',
    '-rtsp_transport',
    'udp',
  ]);
  assert.equal(args.includes('-fflags'), false);
  assert.equal(args.includes('-analyzeduration'), false);
  assert.equal(args.includes('-probesize'), false);
  assert.equal(args.includes('-flush_packets'), false);
  assert.equal(args.includes('phone-av-bridge-mic'), true);
});
