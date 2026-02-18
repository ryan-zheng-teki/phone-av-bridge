import test from 'node:test';
import assert from 'node:assert/strict';
import { SessionController } from '../../core/session-controller.mjs';

function buildController({ speakerCapability = true } = {}) {
  const calls = {
    setDeviceIdentity: 0,
    lastDeviceIdentity: null,
    setStreamUrl: 0,
    lastStreamUrl: null,
    startCamera: 0,
    stopCamera: 0,
    startMicrophoneRoute: 0,
    stopMicrophoneRoute: 0,
    startSpeakerRoute: 0,
    stopSpeakerRoute: 0,
    attachSpeakerClient: 0,
    stopAll: 0,
    cameraHealthy: true,
    microphoneHealthy: true,
    speakerHealthy: true,
  };

  const cameraAdapter = {
    setDeviceIdentity(identity) {
      calls.setDeviceIdentity += 1;
      calls.lastDeviceIdentity = identity;
    },
    getCameraDeviceName() {
      return 'Mock Camera Device';
    },
    setStreamUrl(url) {
      calls.setStreamUrl += 1;
      calls.lastStreamUrl = url;
    },
    async startCamera() {
      calls.startCamera += 1;
      calls.cameraHealthy = true;
    },
    async stopCamera() {
      calls.stopCamera += 1;
      calls.cameraHealthy = false;
    },
    isCameraRunning() {
      return calls.cameraHealthy;
    },
  };

  const audioAdapter = {
    setDeviceIdentity(identity) {
      calls.setDeviceIdentity += 1;
      calls.lastDeviceIdentity = identity;
    },
    getMicrophoneDeviceName() {
      return 'Mock Microphone Device';
    },
    getSpeakerDeviceName() {
      return speakerCapability ? 'Mock Speaker Device' : null;
    },
    async startMicrophoneRoute() {
      calls.startMicrophoneRoute += 1;
      calls.microphoneHealthy = true;
    },
    async stopMicrophoneRoute() {
      calls.stopMicrophoneRoute += 1;
      calls.microphoneHealthy = false;
    },
    async startSpeakerRoute() {
      calls.startSpeakerRoute += 1;
      calls.speakerHealthy = true;
    },
    async stopSpeakerRoute() {
      calls.stopSpeakerRoute += 1;
      calls.speakerHealthy = false;
    },
    attachSpeakerClient() {
      calls.attachSpeakerClient += 1;
    },
    async stopAll() {
      calls.stopAll += 1;
      calls.microphoneHealthy = false;
      calls.speakerHealthy = false;
    },
    isMicrophoneRunning() {
      return calls.microphoneHealthy;
    },
    isSpeakerRunning() {
      return calls.speakerHealthy;
    },
  };

  const controller = new SessionController({
    cameraAdapter,
    audioAdapter,
    capabilities: {
      camera: true,
      microphone: true,
      speaker: speakerCapability,
    },
  });

  return { controller, calls };
}

test('pair/unpair and toggle transitions update host status', async () => {
  const { controller, calls } = buildController();

  await controller.pairHost('PAIR-1234');
  let status = controller.getStatus();
  assert.equal(status.hostStatus, 'Paired');
  assert.equal(status.paired, true);

  await controller.applyResourceState({ camera: true, microphone: true, speaker: true });
  status = controller.getStatus();
  assert.equal(status.hostStatus, 'Resource Active');
  assert.equal(status.resources.camera, true);
  assert.equal(status.resources.microphone, true);
  assert.equal(status.resources.speaker, true);
  assert.equal(calls.startCamera, 1);
  assert.equal(calls.startMicrophoneRoute, 1);
  assert.equal(calls.startSpeakerRoute, 1);

  await controller.unpairHost();
  status = controller.getStatus();
  assert.equal(status.hostStatus, 'Not Paired');
  assert.equal(status.paired, false);
  assert.equal(status.resources.camera, false);
  assert.equal(status.resources.microphone, false);
  assert.equal(status.resources.speaker, false);
});

test('unsupported speaker capability yields needs attention state', async () => {
  const { controller } = buildController({ speakerCapability: false });
  await controller.pairHost('PAIR-5678');

  const status = await controller.applyResourceState({ speaker: true });
  assert.equal(status.hostStatus, 'Needs Attention');
  assert.equal(status.resources.speaker, false);
  assert.equal(status.issues.length, 1);
  assert.match(status.issues[0].message, /Speaker route could not be started|Speaker capture device is unavailable/);
});

test('camera stream URL is passed to camera adapter before start', async () => {
  const { controller, calls } = buildController();
  await controller.pairHost('PAIR-9012');
  const streamUrl = 'rtsp://192.168.1.20:1935/';

  await controller.applyResourceState({ camera: true, cameraStreamUrl: streamUrl });
  const status = controller.getStatus();

  assert.equal(calls.setStreamUrl, 1);
  assert.equal(calls.lastStreamUrl, streamUrl);
  assert.equal(status.cameraStreamUrl, streamUrl);
  assert.equal(status.resources.camera, true);
});

test('microphone-only routing keeps stream URL and starts microphone route', async () => {
  const { controller, calls } = buildController();
  await controller.pairHost('PAIR-3456');
  const streamUrl = 'rtsp://192.168.1.42:1935/';

  const status = await controller.applyResourceState({
    camera: false,
    microphone: true,
    cameraStreamUrl: streamUrl,
  });

  assert.equal(status.resources.camera, false);
  assert.equal(status.resources.microphone, true);
  assert.equal(status.cameraStreamUrl, streamUrl);
  assert.equal(calls.startMicrophoneRoute, 1);
});

test('device identity is persisted and forwarded to adapters', async () => {
  const { controller, calls } = buildController();
  await controller.pairHost('PAIR-7890', { deviceName: 'Pixel 8', deviceId: 'android-abc123' });

  const status = controller.getStatus();
  assert.equal(status.phone.deviceName, 'Pixel 8');
  assert.equal(status.phone.deviceId, 'android-abc123');
  assert.equal(calls.setDeviceIdentity >= 1, true);
  assert.equal(status.routeHints.camera, 'Mock Camera Device');
  assert.equal(status.routeHints.microphone, 'Mock Microphone Device');
});

test('phone presence updates identity before pairing and survives unpair', async () => {
  const { controller } = buildController();
  let status = controller.notePhonePresence({ deviceName: 'Pixel 9 Pro', deviceId: 'android-xyz999' });
  assert.equal(status.paired, false);
  assert.equal(status.hostStatus, 'Not Paired');
  assert.equal(status.phone.deviceName, 'Pixel 9 Pro');
  assert.equal(status.phone.deviceId, 'android-xyz999');

  await controller.pairHost('PAIR-2468');
  await controller.unpairHost();
  status = controller.getStatus();
  assert.equal(status.paired, false);
  assert.equal(status.hostStatus, 'Not Paired');
  assert.equal(status.phone.deviceName, 'Pixel 9 Pro');
  assert.equal(status.phone.deviceId, 'android-xyz999');
});

test('speaker stream attachment requires active speaker route', async () => {
  const { controller, calls } = buildController();
  await controller.pairHost('PAIR-2468');

  assert.throws(() => controller.attachSpeakerStream({}), /Speaker route is not active/);

  await controller.applyResourceState({ speaker: true });
  controller.attachSpeakerStream({});
  assert.equal(calls.attachSpeakerClient, 1);
});

test('health probe failure bypasses fast-path and re-applies dead routes', async () => {
  const { controller, calls } = buildController();
  await controller.pairHost('PAIR-0001');

  await controller.applyResourceState({
    camera: true,
    microphone: true,
    speaker: true,
    cameraStreamUrl: 'rtsp://192.168.1.100:1935/',
  });
  assert.equal(calls.startCamera, 1);
  assert.equal(calls.startMicrophoneRoute, 1);
  assert.equal(calls.startSpeakerRoute, 1);

  calls.cameraHealthy = false;
  calls.microphoneHealthy = false;

  const status = await controller.applyResourceState({
    camera: true,
    microphone: true,
    speaker: true,
    cameraStreamUrl: 'rtsp://192.168.1.100:1935/',
  });

  assert.equal(calls.startCamera, 2);
  assert.equal(calls.startMicrophoneRoute, 2);
  assert.equal(status.hostStatus, 'Resource Active');
  assert.equal(status.resources.camera, true);
  assert.equal(status.resources.microphone, true);
  assert.equal(status.resources.speaker, true);
});

test('camera lens and orientation metadata are tracked in status', async () => {
  const { controller } = buildController();
  await controller.pairHost('PAIR-4455');

  let status = await controller.applyResourceState({
    camera: true,
    cameraLens: 'front',
    cameraOrientationMode: 'portrait_lock',
  });

  assert.equal(status.phoneCamera.lens, 'front');
  assert.equal(status.phoneCamera.orientationMode, 'portrait_lock');

  status = await controller.applyResourceState({
    camera: true,
    cameraLens: 'back',
    cameraOrientationMode: 'landscape_lock',
  });
  assert.equal(status.phoneCamera.lens, 'back');
  assert.equal(status.phoneCamera.orientationMode, 'landscape_lock');
});
