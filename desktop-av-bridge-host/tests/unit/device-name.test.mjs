import test from 'node:test';
import assert from 'node:assert/strict';
import { buildDeviceNames, compactId, normalizeDeviceIdentity, slugify } from '../../adapters/common/device-name.mjs';

test('normalizeDeviceIdentity keeps defaults when values are missing', () => {
  const result = normalizeDeviceIdentity({}, { deviceName: 'Pixel', deviceId: 'abc' });
  assert.deepEqual(result, { deviceName: 'Pixel', deviceId: 'abc' });
});

test('normalizeDeviceIdentity trims and clamps values', () => {
  const result = normalizeDeviceIdentity(
    { deviceName: '   Very Long Phone Name That Should Be Clamped At A Safe Length   ', deviceId: '  dev-123  ' },
    {}
  );
  assert.ok(result.deviceName.length <= 48);
  assert.equal(result.deviceId, 'dev-123');
});

test('slugify and compactId produce route-safe fragments', () => {
  assert.equal(slugify('Pixel 8 Pro'), 'pixel_8_pro');
  assert.equal(compactId('android-AB:12:34:56'), 'roidab123456');
});

test('buildDeviceNames prefixes all resources with phone name', () => {
  const labels = buildDeviceNames('Pixel 8', {
    cameraTarget: '/dev/video2',
    microphoneTarget: 'Pixel_8_Mic',
    speakerTarget: 'default.monitor',
  });
  assert.match(labels.camera, /^Pixel 8 Camera/);
  assert.match(labels.microphone, /^Pixel 8 Microphone/);
  assert.match(labels.speaker, /^Pixel 8 Speaker/);
});
