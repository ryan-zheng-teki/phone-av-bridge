import test from 'node:test';
import assert from 'node:assert/strict';
import { parseFfmpegAvfoundationDeviceList } from '../../adapters/macos-firstparty-audio/driver-probe.mjs';

test('parseFfmpegAvfoundationDeviceList extracts audio and video sections', () => {
  const stderr = [
    '[AVFoundation indev @ 0x123] AVFoundation video devices:',
    '[AVFoundation indev @ 0x123] [0] FaceTime HD Camera',
    '[AVFoundation indev @ 0x123] [1] Phone AV Bridge Camera',
    '[AVFoundation indev @ 0x123] AVFoundation audio devices:',
    '[AVFoundation indev @ 0x123] [0] MacBook Pro Microphone',
    '[AVFoundation indev @ 0x123] [1] PhoneAVBridgeAudio 2ch',
  ].join('\n');

  const result = parseFfmpegAvfoundationDeviceList(stderr);
  assert.equal(result.video.length, 2);
  assert.equal(result.audio.length, 2);
  assert.equal(result.audio[1].name, 'PhoneAVBridgeAudio 2ch');
  assert.equal(result.audio[1].index, 1);
});

test('parseFfmpegAvfoundationDeviceList ignores lines outside sections', () => {
  const stderr = [
    'random intro',
    '[AVFoundation indev @ 0x123] [0] should not parse yet',
    '[AVFoundation indev @ 0x123] AVFoundation audio devices:',
    '[AVFoundation indev @ 0x123] [2] Phone AV Bridge Audio',
    'other text',
  ].join('\n');

  const result = parseFfmpegAvfoundationDeviceList(stderr);
  assert.equal(result.video.length, 0);
  assert.equal(result.audio.length, 1);
  assert.equal(result.audio[0].index, 2);
  assert.equal(result.audio[0].name, 'Phone AV Bridge Audio');
});
