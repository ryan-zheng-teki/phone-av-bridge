import test from 'node:test';
import assert from 'node:assert/strict';
import { setTimeout as delay } from 'node:timers/promises';
import crypto from 'node:crypto';
import { startServer } from '../../desktop-app/server.mjs';

const HOST = '127.0.0.1';

function randomPort() {
  return 22000 + crypto.randomInt(0, 8000);
}

async function request(port, path, method = 'GET', body) {
  const response = await fetch(`http://${HOST}:${port}${path}`, {
    method,
    headers: body ? { 'Content-Type': 'application/json' } : undefined,
    body: body ? JSON.stringify(body) : undefined,
  });
  const payload = await response.json();
  return { response, payload };
}

test('qr token can be issued and redeemed exactly once', async () => {
  const port = randomPort();
  const app = await startServer({
    host: HOST,
    port,
    useMockAdapters: true,
    enableDiscovery: false,
    qrTokenTtlMs: 30_000,
  });

  try {
    let result = await request(port, '/api/bootstrap/qr-token', 'POST');
    assert.equal(result.response.status, 200);
    assert.equal(result.payload.qrToken.payload.service, 'phone-av-bridge');
    assert.equal(result.payload.qrToken.payload.version, 1);
    assert.equal(typeof result.payload.qrToken.payload.baseUrl, 'string');
    assert.ok(result.payload.qrToken.payload.baseUrl.startsWith('http://'));
    assert.equal(typeof result.payload.qrToken.token, 'string');
    assert.ok(result.payload.qrToken.token.length > 10);
    assert.equal(typeof result.payload.qrToken.payloadText, 'string');
    assert.ok(result.payload.qrToken.payloadText.includes('"token"'));
    assert.equal(typeof result.payload.qrToken.qrImageDataUrl, 'string');
    assert.ok(result.payload.qrToken.qrImageDataUrl.startsWith('data:image/png;base64,'));

    const token = result.payload.qrToken.token;

    result = await request(port, '/api/bootstrap/qr-redeem', 'POST', { token });
    assert.equal(result.response.status, 200);
    assert.equal(result.payload.bootstrap.service, 'phone-av-bridge');
    assert.ok(result.payload.bootstrap.pairingCode.startsWith('PAIR-'));

    result = await request(port, '/api/bootstrap/qr-redeem', 'POST', { token });
    assert.equal(result.response.status, 400);
    assert.match(result.payload.error, /already been used/i);
  } finally {
    await app.close();
  }
});

test('expired qr token cannot be redeemed', async () => {
  const port = randomPort();
  const app = await startServer({
    host: HOST,
    port,
    useMockAdapters: true,
    enableDiscovery: false,
    qrTokenTtlMs: 1000,
  });

  try {
    let result = await request(port, '/api/bootstrap/qr-token', 'POST');
    assert.equal(result.response.status, 200);
    const token = result.payload.qrToken.token;

    await delay(1300);

    result = await request(port, '/api/bootstrap/qr-redeem', 'POST', { token });
    assert.equal(result.response.status, 400);
    assert.match(result.payload.error, /invalid or expired/i);
  } finally {
    await app.close();
  }
});
