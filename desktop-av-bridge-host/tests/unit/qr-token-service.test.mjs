import test from 'node:test';
import assert from 'node:assert/strict';
import { Buffer } from 'node:buffer';
import {
  createQrTokenService,
  DEFAULT_QR_TOKEN_TTL_MS,
} from '../../desktop-app/services/qr-token-service.mjs';

function createBootstrap() {
  return {
    service: 'phone-av-bridge',
    hostId: 'host-abc12345',
    displayName: 'test-host',
    baseUrl: 'http://127.0.0.1:8787',
  };
}

test('issueQrToken returns payload and qr image data', async () => {
  let nowMs = 1_700_000_000_000;
  const service = createQrTokenService({
    bootstrap: createBootstrap(),
    qrTokenTtlMs: 30_000,
    now: () => nowMs,
    randomBytes: () => Buffer.alloc(24, 1),
    qrCodeToDataUrl: async () => 'data:image/png;base64,test',
  });

  const qrToken = await service.issueQrToken();
  assert.equal(qrToken.token, Buffer.alloc(24, 1).toString('base64url'));
  assert.equal(qrToken.expiresAt, new Date(nowMs + 30_000).toISOString());
  assert.equal(qrToken.payload.service, 'phone-av-bridge');
  assert.equal(qrToken.payload.version, 1);
  assert.equal(qrToken.payload.baseUrl, 'http://127.0.0.1:8787');
  assert.equal(qrToken.payload.hostId, 'host-abc12345');
  assert.equal(qrToken.payload.displayName, 'test-host');
  assert.equal(typeof qrToken.payloadText, 'string');
  assert.ok(qrToken.payloadText.includes('"token"'));
  assert.equal(qrToken.qrImageDataUrl, 'data:image/png;base64,test');
});

test('issueQrToken falls back to null image when QR renderer fails', async () => {
  const service = createQrTokenService({
    bootstrap: createBootstrap(),
    qrCodeToDataUrl: async () => {
      throw new Error('render failed');
    },
  });

  const qrToken = await service.issueQrToken();
  assert.equal(typeof qrToken.token, 'string');
  assert.equal(qrToken.qrImageDataUrl, null);
});

test('redeemQrToken enforces required, single-use, and expiry semantics', async () => {
  let nowMs = 1_700_000_000_000;
  const service = createQrTokenService({
    bootstrap: createBootstrap(),
    qrTokenTtlMs: 1_500,
    now: () => nowMs,
    randomBytes: () => Buffer.alloc(24, 2),
    qrCodeToDataUrl: async () => 'data:image/png;base64,test',
  });

  const qrToken = await service.issueQrToken();

  assert.throws(() => service.redeemQrToken(''), /QR token is required/);

  const redeemed = service.redeemQrToken(`  ${qrToken.token}  `);
  assert.equal(redeemed.bootstrap.hostId, 'host-abc12345');

  assert.throws(() => service.redeemQrToken(qrToken.token), /already been used/i);

  const expiringService = createQrTokenService({
    bootstrap: createBootstrap(),
    qrTokenTtlMs: 1_000,
    now: () => nowMs,
    randomBytes: () => Buffer.alloc(24, 3),
    qrCodeToDataUrl: async () => 'data:image/png;base64,test',
  });

  const expiringToken = await expiringService.issueQrToken();
  nowMs += 1_001;
  assert.throws(() => expiringService.redeemQrToken(expiringToken.token), /invalid or expired/i);
});

test('ttl lower bound and default ttl are applied', async () => {
  let nowMs = 1_700_000_000_000;

  const minTtlService = createQrTokenService({
    bootstrap: createBootstrap(),
    qrTokenTtlMs: 1,
    now: () => nowMs,
    qrCodeToDataUrl: async () => 'data:image/png;base64,test',
  });
  const minTtlToken = await minTtlService.issueQrToken();
  assert.equal(minTtlToken.expiresAt, new Date(nowMs + 1_000).toISOString());

  const defaultTtlService = createQrTokenService({
    bootstrap: createBootstrap(),
    now: () => nowMs,
    qrCodeToDataUrl: async () => 'data:image/png;base64,test',
  });
  const defaultTtlToken = await defaultTtlService.issueQrToken();
  assert.equal(defaultTtlToken.expiresAt, new Date(nowMs + DEFAULT_QR_TOKEN_TTL_MS).toISOString());
});
