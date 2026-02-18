import http from 'node:http';
import dgram from 'node:dgram';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { SessionController } from '../core/session-controller.mjs';
import { runPreflight } from '../core/preflight-service.mjs';
import { LinuxCameraBridgeRunner, MockCameraAdapter } from '../adapters/linux-camera/bridge-runner.mjs';
import { LinuxAudioRunner, MockAudioAdapter } from '../adapters/linux-audio/audio-runner.mjs';
import { MacOsCameraExtensionRunner, MockMacCameraAdapter } from '../adapters/macos-firstparty-camera/cameraextension-runner.mjs';
import { MacOsFirstPartyAudioRunner, MockMacAudioAdapter } from '../adapters/macos-firstparty-audio/audio-runner.mjs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const staticRoot = path.join(__dirname, 'static');
const DISCOVERY_MAGIC = 'PHONE_RESOURCE_COMPANION_DISCOVER_V1';
const DEFAULT_STATE_FILE = path.join(os.homedir(), '.host-resource-agent', 'state.json');

function resolveAdvertisedHost(bindHost) {
  if (bindHost !== '0.0.0.0') {
    return bindHost;
  }

  const interfaces = os.networkInterfaces();
  for (const values of Object.values(interfaces)) {
    for (const item of values ?? []) {
      if (item.family === 'IPv4' && !item.internal) {
        return item.address;
      }
    }
  }
  return '127.0.0.1';
}

function generatePairingCode() {
  const digits = (crypto.randomInt(0, 900000) + 100000).toString();
  return `PAIR-${digits}`;
}

function normalizePairingCode(value) {
  if (typeof value !== 'string') {
    return null;
  }
  const normalized = value.trim().toUpperCase();
  return /^PAIR-[A-Z0-9]{4,32}$/.test(normalized) ? normalized : null;
}

function resolveStateFilePath() {
  const custom = (process.env.HOST_STATE_FILE || '').trim();
  return custom || DEFAULT_STATE_FILE;
}

async function readPersistedState(stateFilePath) {
  try {
    const content = await fs.readFile(stateFilePath, 'utf8');
    const parsed = JSON.parse(content);
    const pairingCode = normalizePairingCode(parsed?.pairingCode);
    const paired = parsed?.paired === true;
    const deviceName = typeof parsed?.phone?.deviceName === 'string' ? parsed.phone.deviceName.trim() : '';
    const deviceId = typeof parsed?.phone?.deviceId === 'string' ? parsed.phone.deviceId.trim() : '';
    return {
      pairingCode,
      paired,
      phone: {
        deviceName: deviceName || null,
        deviceId: deviceId || null,
      },
    };
  } catch {
    return null;
  }
}

async function writePersistedState(stateFilePath, snapshot) {
  const payload = {
    pairingCode: snapshot.pairingCode,
    paired: !!snapshot.paired,
    phone: {
      deviceName: snapshot.phone?.deviceName || null,
      deviceId: snapshot.phone?.deviceId || null,
    },
    updatedAt: new Date().toISOString(),
  };
  await fs.mkdir(path.dirname(stateFilePath), { recursive: true });
  await fs.writeFile(stateFilePath, JSON.stringify(payload, null, 2), 'utf8');
}

function jsonResponse(res, statusCode, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
  });
  res.end(body);
}

async function readBody(req) {
  const chunks = [];
  for await (const chunk of req) {
    chunks.push(chunk);
  }
  if (chunks.length === 0) {
    return {};
  }
  try {
    return JSON.parse(Buffer.concat(chunks).toString('utf8'));
  } catch {
    throw new Error('Invalid JSON body.');
  }
}

function contentTypeFor(filePath) {
  if (filePath.endsWith('.html')) return 'text/html; charset=utf-8';
  if (filePath.endsWith('.js')) return 'application/javascript; charset=utf-8';
  if (filePath.endsWith('.css')) return 'text/css; charset=utf-8';
  return 'text/plain; charset=utf-8';
}

async function serveStatic(req, res) {
  const pathname = req.url === '/' ? '/index.html' : req.url;
  const safePath = pathname.replace(/\.\./g, '');
  const filePath = path.join(staticRoot, safePath);

  try {
    const data = await fs.readFile(filePath);
    res.writeHead(200, {
      'Content-Type': contentTypeFor(filePath),
      'Cache-Control': 'no-store',
    });
    res.end(data);
  } catch {
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Not found');
  }
}

function createController({ useMockAdapters }) {
  const platform = process.env.HOST_PLATFORM || process.platform;

  if (useMockAdapters) {
    return new SessionController({
      cameraAdapter: platform === 'darwin' ? new MockMacCameraAdapter() : new MockCameraAdapter(),
      audioAdapter: platform === 'darwin' ? new MockMacAudioAdapter({ enableSpeaker: true }) : new MockAudioAdapter({ enableSpeaker: true }),
      capabilities: {
        camera: true,
        microphone: true,
        speaker: true,
      },
    });
  }

  if (platform === 'linux') {
    return new SessionController({
      cameraAdapter: new LinuxCameraBridgeRunner({
        streamUrl: process.env.STREAM_SOURCE_URL || '',
        cameraMode: process.env.LINUX_CAMERA_MODE || 'compatibility',
        v4l2Device: process.env.V4L2_DEVICE || '/dev/video2',
        maxSeconds: process.env.MAX_SECONDS || '0',
      }),
      audioAdapter: new LinuxAudioRunner({
        enableSpeaker: true,
        streamUrl: process.env.STREAM_SOURCE_URL || '',
      }),
      capabilities: {
        camera: true,
        microphone: true,
        speaker: true,
      },
    });
  }

  if (platform === 'darwin') {
    return new SessionController({
      cameraAdapter: new MacOsCameraExtensionRunner({
        streamUrl: process.env.STREAM_SOURCE_URL || '',
        frameHost: process.env.MACOS_CAMERA_FRAME_HOST || '127.0.0.1',
        framePort: Number(process.env.MACOS_CAMERA_FRAME_PORT || 39501),
        hostAppPath: process.env.MACOS_CAMERA_EXTENSION_APP || '',
      }),
      audioAdapter: new MacOsFirstPartyAudioRunner({
        streamUrl: process.env.STREAM_SOURCE_URL || '',
        enableSpeaker: true,
        outputDeviceName: process.env.MACOS_AUDIO_OUTPUT_DEVICE || 'PRCAudio 2ch',
      }),
      capabilities: {
        camera: true,
        microphone: true,
        speaker: true,
      },
    });
  }

  return new SessionController({
    cameraAdapter: new MockCameraAdapter(),
    audioAdapter: new MockAudioAdapter({ enableSpeaker: false }),
    capabilities: {
      camera: false,
      microphone: false,
      speaker: false,
    },
  });
}

export function createApp({
  useMockAdapters = false,
  host = '127.0.0.1',
  port = 8787,
  advertisedHost = '',
  pairingCode = generatePairingCode(),
} = {}) {
  const controller = createController({ useMockAdapters });
  let preflightReport = null;
  const hostForClients = (advertisedHost || '').trim() || resolveAdvertisedHost(host);
  const bootstrap = {
    service: 'phone-resource-companion',
    host: hostForClients,
    port,
    pairingCode,
    baseUrl: `http://${hostForClients}:${port}`,
  };

  const server = http.createServer(async (req, res) => {
    try {
      if (req.method === 'GET' && req.url === '/health') {
        return jsonResponse(res, 200, { ok: true, service: 'host-resource-agent' });
      }

      if (req.method === 'GET' && req.url === '/api/status') {
        return jsonResponse(res, 200, {
          status: controller.getStatus(),
          preflight: preflightReport,
          bootstrap,
        });
      }

      if (req.method === 'GET' && req.url === '/api/speaker/stream') {
        controller.attachSpeakerStream(res);
        return;
      }

      if (req.method === 'GET' && req.url === '/api/bootstrap') {
        return jsonResponse(res, 200, { bootstrap });
      }

      if (req.method === 'POST' && req.url === '/api/preflight') {
        preflightReport = await runPreflight(process.platform);
        return jsonResponse(res, 200, { preflight: preflightReport });
      }

      if (req.method === 'POST' && req.url === '/api/pair') {
        const body = await readBody(req);
        if ((body.pairCode || '') !== pairingCode) {
          throw new Error('Invalid pair code.');
        }
        const status = await controller.pairHost(body.pairCode || '', {
          deviceName: typeof body.deviceName === 'string' ? body.deviceName.trim() : undefined,
          deviceId: typeof body.deviceId === 'string' ? body.deviceId.trim() : undefined,
        });
        return jsonResponse(res, 200, { status });
      }

      if (req.method === 'POST' && req.url === '/api/presence') {
        const body = await readBody(req);
        const status = controller.notePhonePresence({
          deviceName: typeof body.deviceName === 'string' ? body.deviceName.trim() : undefined,
          deviceId: typeof body.deviceId === 'string' ? body.deviceId.trim() : undefined,
        });
        return jsonResponse(res, 200, { status });
      }

      if (req.method === 'POST' && req.url === '/api/unpair') {
        const status = await controller.unpairHost();
        return jsonResponse(res, 200, { status });
      }

      if (req.method === 'POST' && req.url === '/api/toggles') {
        const body = await readBody(req);
        const status = await controller.applyResourceState({
          camera: !!body.camera,
          microphone: !!body.microphone,
          speaker: !!body.speaker,
          cameraLens: typeof body.cameraLens === 'string' ? body.cameraLens.trim() : undefined,
          cameraOrientationMode: typeof body.cameraOrientationMode === 'string' ? body.cameraOrientationMode.trim() : undefined,
          cameraStreamUrl: typeof body.cameraStreamUrl === 'string' ? body.cameraStreamUrl.trim() : undefined,
          deviceName: typeof body.deviceName === 'string' ? body.deviceName.trim() : undefined,
          deviceId: typeof body.deviceId === 'string' ? body.deviceId.trim() : undefined,
        });
        return jsonResponse(res, 200, { status });
      }

      if (req.method === 'GET') {
        return serveStatic(req, res);
      }

      return jsonResponse(res, 404, { error: 'Not found' });
    } catch (error) {
      return jsonResponse(res, 400, { error: error.message || 'Request failed' });
    }
  });

  return { server, controller, bootstrap };
}

export async function startServer({
  host = '0.0.0.0',
  port = 8787,
  advertisedHost = '',
  useMockAdapters = false,
  enableDiscovery = true,
  discoveryPort = 39888,
} = {}) {
  const persistenceEnabled = !useMockAdapters && process.env.PERSIST_STATE !== '0';
  const stateFilePath = resolveStateFilePath();
  const persistedState = persistenceEnabled ? await readPersistedState(stateFilePath) : null;
  const pairingCode = persistedState?.pairingCode || generatePairingCode();

  const { server, bootstrap, controller } = createApp({
    useMockAdapters,
    host,
    port,
    advertisedHost,
    pairingCode,
  });

  if (persistedState?.paired) {
    await controller.pairHost(pairingCode, {
      deviceName: persistedState.phone?.deviceName || undefined,
      deviceId: persistedState.phone?.deviceId || undefined,
    });
  } else if (persistedState?.phone?.deviceName || persistedState?.phone?.deviceId) {
    controller.notePhonePresence({
      deviceName: persistedState.phone?.deviceName || undefined,
      deviceId: persistedState.phone?.deviceId || undefined,
    });
  }

  if (persistenceEnabled) {
    let writeQueue = Promise.resolve();
    const enqueuePersist = () => {
      writeQueue = writeQueue
        .then(async () => {
          const status = controller.getStatus();
          await writePersistedState(stateFilePath, {
            pairingCode,
            paired: status.paired,
            phone: status.phone,
          });
        })
        .catch((error) => {
          console.error(`state persistence failed: ${error.message}`);
        });
    };
    controller.on('status', enqueuePersist);
    enqueuePersist();
  }

  await new Promise((resolve) => {
    server.listen(port, host, resolve);
  });

  let discoverySocket = null;
  if (enableDiscovery) {
    discoverySocket = dgram.createSocket('udp4');

    discoverySocket.on('message', (message, remoteInfo) => {
      const payload = message.toString('utf8').trim();
      if (payload !== DISCOVERY_MAGIC) {
        return;
      }
      const response = Buffer.from(JSON.stringify(bootstrap), 'utf8');
      discoverySocket.send(response, remoteInfo.port, remoteInfo.address);
    });

    await new Promise((resolve) => {
      discoverySocket.bind(discoveryPort, '0.0.0.0', resolve);
    });
  }

  return {
    host,
    port,
    bootstrap,
    close: async () => {
      if (discoverySocket) {
        await new Promise((resolve) => discoverySocket.close(() => resolve()));
      }
      await new Promise((resolve, reject) => {
        server.close((error) => (error ? reject(error) : resolve()));
      });
    },
  };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const useMockAdapters = process.env.USE_MOCK_ADAPTERS === '1';
  // Avoid accidental binding/advertising drift from generic HOST envs.
  const host = process.env.HOST_BIND || '0.0.0.0';
  const port = Number(process.env.PORT || '8787');
  const advertisedHost = process.env.ADVERTISED_HOST || '';
  const enableDiscovery = process.env.ENABLE_DISCOVERY !== '0';
  const discoveryPort = Number(process.env.DISCOVERY_PORT || '39888');

  startServer({ host, port, advertisedHost, useMockAdapters, enableDiscovery, discoveryPort })
    .then((app) => {
      console.log(`host-resource-agent running at ${app.bootstrap.baseUrl} (mock=${useMockAdapters})`);
      console.log(`pairing code: ${app.bootstrap.pairingCode}`);
      if (enableDiscovery) {
        console.log(`discovery udp port: ${discoveryPort}`);
      }
    })
    .catch((error) => {
      console.error(`failed to start host-resource-agent: ${error.message}`);
      process.exit(1);
    });
}
