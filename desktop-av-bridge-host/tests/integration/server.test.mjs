import test from 'node:test';
import assert from 'node:assert/strict';
import { startServer } from '../../desktop-app/server.mjs';

const HOST = '127.0.0.1';
const PORT = 18787;

async function request(path, method = 'GET', body) {
  const response = await fetch(`http://${HOST}:${PORT}${path}`, {
    method,
    headers: body ? { 'Content-Type': 'application/json' } : undefined,
    body: body ? JSON.stringify(body) : undefined,
  });
  const payload = await response.json();
  return { response, payload };
}

test('server status and pair/toggle flow works in mock mode', async () => {
  const app = await startServer({ host: HOST, port: PORT, useMockAdapters: true, enableDiscovery: false });

  try {
    let result = await request('/api/bootstrap');
    assert.equal(result.response.status, 200);
    assert.match(result.payload.bootstrap.hostId, /^host-[a-z0-9]{8,40}$/);
    assert.equal(typeof result.payload.bootstrap.displayName, 'string');
    assert.equal(typeof result.payload.bootstrap.platform, 'string');
    assert.ok(result.payload.bootstrap.pairingCode.startsWith('PAIR-'));

    const pairCode = result.payload.bootstrap.pairingCode;

    result = await request('/api/pair', 'POST', { pairCode: 'WRONG-CODE' });
    assert.equal(result.response.status, 400);
    assert.match(result.payload.error, /Invalid pair code/);

    result = await request('/api/status');
    assert.equal(result.response.status, 200);
    assert.equal(result.payload.status.paired, false);

    result = await request('/api/presence', 'POST', {
      deviceName: 'Pixel 8',
      deviceId: 'android-prepair-1',
    });
    assert.equal(result.response.status, 200);
    assert.equal(result.payload.status.paired, false);
    assert.equal(result.payload.status.phone.deviceName, 'Pixel 8');
    assert.equal(result.payload.status.phone.deviceId, 'android-prepair-1');

    result = await request('/api/pair', 'POST', { pairCode });
    assert.equal(result.response.status, 200);
    assert.equal(result.payload.status.paired, true);

    result = await request('/api/toggles', 'POST', {
      camera: true,
      microphone: true,
      speaker: true,
      cameraLens: 'front',
      cameraOrientationMode: 'portrait_lock',
    });
    assert.equal(result.response.status, 200);
    assert.equal(result.payload.status.hostStatus, 'Resource Active');
    assert.equal(result.payload.status.phoneCamera.lens, 'front');
    assert.equal(result.payload.status.phoneCamera.orientationMode, 'portrait_lock');

    result = await request('/api/preflight', 'POST');
    assert.equal(result.response.status, 200);
    assert.ok(result.payload.preflight.status);

    result = await request('/api/unpair', 'POST');
    assert.equal(result.response.status, 200);
    assert.equal(result.payload.status.paired, false);
    assert.equal(result.payload.status.phone.deviceName, 'Pixel 8');
    assert.equal(result.payload.status.phone.deviceId, 'android-prepair-1');
  } finally {
    await app.close();
  }
});
