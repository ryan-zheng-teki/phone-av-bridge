import test from 'node:test';
import assert from 'node:assert/strict';
import dgram from 'node:dgram';
import { startServer } from '../../desktop-app/server.mjs';

const HOST = '127.0.0.1';
const PORT = 18788;
const DISCOVERY_PORT = 39901;
const MAGIC = 'PHONE_AV_BRIDGE_DISCOVER_V1';

test('udp discovery responds with bootstrap payload', async () => {
  const app = await startServer({
    host: HOST,
    port: PORT,
    useMockAdapters: true,
    enableDiscovery: true,
    discoveryPort: DISCOVERY_PORT,
  });

  const socket = dgram.createSocket('udp4');

  try {
    const response = await new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        reject(new Error('discovery timeout'));
      }, 2000);

      socket.on('message', (msg) => {
        clearTimeout(timeout);
        resolve(msg.toString('utf8'));
      });

      socket.bind(() => {
        socket.send(Buffer.from(MAGIC, 'utf8'), DISCOVERY_PORT, HOST, (error) => {
          if (error) {
            clearTimeout(timeout);
            reject(error);
          }
        });
      });
    });

    const payload = JSON.parse(response);
    assert.equal(payload.service, 'phone-av-bridge');
    assert.equal(payload.port, PORT);
    assert.ok(payload.pairingCode.startsWith('PAIR-'));
  } finally {
    socket.close();
    await app.close();
  }
});
