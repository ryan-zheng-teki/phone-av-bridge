import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { LinuxCameraBridgeRunner } from '../../adapters/linux-camera/bridge-runner.mjs';

async function createIgnoringTermScript() {
  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'pavb-linux-camera-test-'));
  const scriptPath = path.join(tempDir, 'ignore-term.sh');
  const scriptBody = `#!/usr/bin/env bash
set -euo pipefail
trap '' TERM
sleep 10
`;
  await fs.writeFile(scriptPath, scriptBody, { mode: 0o755 });
  return {
    scriptPath,
    cleanup: async () => {
      await fs.rm(tempDir, { recursive: true, force: true });
    },
  };
}

function pidAlive(pid) {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

test('stopCamera force-kills child when SIGTERM is ignored', async (t) => {
  const { scriptPath, cleanup } = await createIgnoringTermScript();
  t.after(async () => {
    await cleanup();
  });

  const runner = new LinuxCameraBridgeRunner({
    scriptPath,
    streamUrl: 'rtsp://127.0.0.1:8554/live',
    cameraMode: 'userspace',
  });

  await runner.startCamera();
  const pid = runner.process?.pid;
  assert.ok(pid, 'camera child pid should exist after start');

  const startedAt = Date.now();
  await runner.stopCamera();
  const elapsedMs = Date.now() - startedAt;

  assert.equal(runner.isCameraRunning(), false);
  assert.ok(elapsedMs < 2800, `stopCamera should complete quickly, got ${elapsedMs}ms`);
  if (pidAlive(pid)) {
    process.kill(pid, 'SIGKILL');
    assert.fail(`camera child pid ${pid} should not remain alive after stop`);
  }
});

test('stopCamera is a no-op when camera process is not running', async () => {
  const runner = new LinuxCameraBridgeRunner({
    streamUrl: 'rtsp://127.0.0.1:8554/live',
    cameraMode: 'userspace',
  });

  await runner.stopCamera();
  assert.equal(runner.isCameraRunning(), false);
});

test('getCameraDeviceName reflects userspace mode target text', () => {
  const runner = new LinuxCameraBridgeRunner({
    streamUrl: 'rtsp://127.0.0.1:8554/live',
    cameraMode: 'userspace',
  });

  runner.setDeviceIdentity({ deviceName: 'Pixel 9 Pro', deviceId: 'android-xyz' });
  assert.match(runner.getCameraDeviceName(), /userspace ingest mode/i);
});
