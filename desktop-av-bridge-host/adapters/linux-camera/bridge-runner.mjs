import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildDeviceNames, normalizeDeviceIdentity } from '../common/device-name.mjs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, '../../..');

export class LinuxCameraBridgeRunner {
  constructor(options = {}) {
    this.scriptPath = options.scriptPath ?? path.join(repoRoot, 'phone-av-camera-bridge-runtime/bin/run-bridge.sh');
    this.streamUrl = options.streamUrl ?? process.env.STREAM_SOURCE_URL ?? '';
    this.cameraMode = (options.cameraMode ?? process.env.LINUX_CAMERA_MODE ?? 'compatibility').toLowerCase();
    this.v4l2Device = options.v4l2Device ?? process.env.V4L2_DEVICE ?? '/dev/video2';
    this.maxSeconds = options.maxSeconds ?? process.env.MAX_SECONDS ?? '0';
    this.process = null;
    this.activeStreamUrl = '';
    this.deviceName = 'Phone';
    this.deviceId = 'default';
  }

  setStreamUrl(streamUrl) {
    this.streamUrl = (streamUrl || '').trim();
  }

  setDeviceIdentity({ deviceName, deviceId } = {}) {
    const next = normalizeDeviceIdentity({ deviceName, deviceId }, {
      deviceName: this.deviceName,
      deviceId: this.deviceId,
    });
    this.deviceName = next.deviceName;
    this.deviceId = next.deviceId;
  }

  getCameraDeviceName() {
    const backend = this.#resolveBackend();
    if (backend === 'linux-v4l2') {
      return buildDeviceNames(this.deviceName, { cameraTarget: this.v4l2Device }).camera;
    }
    return buildDeviceNames(this.deviceName, { cameraTarget: 'userspace ingest mode' }).camera;
  }

  async startCamera() {
    if (!this.streamUrl) {
      throw new Error('STREAM_SOURCE_URL is required for camera adapter.');
    }
    if (this.process && this.activeStreamUrl === this.streamUrl) {
      return;
    }
    if (this.process) {
      await this.stopCamera();
    }

    this.process = spawn(this.scriptPath, ['--config', '/dev/null'], {
      env: {
        ...process.env,
        STREAM_SOURCE_PROTOCOL: 'rtsp',
        STREAM_SOURCE_URL: this.streamUrl,
        SINK_BACKEND: this.#resolveBackend(),
        V4L2_DEVICE: this.v4l2Device,
        MAX_SECONDS: String(this.maxSeconds),
      },
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    const activeProcess = this.process;
    this.activeStreamUrl = this.streamUrl;

    let startupFailed = false;
    let startupError = '';

    activeProcess.stderr.on('data', (chunk) => {
      const text = chunk.toString();
      if (text.includes('ERROR:')) {
        startupFailed = true;
        startupError = text.trim();
      }
    });

    activeProcess.on('exit', () => {
      if (this.process === activeProcess) {
        this.process = null;
        this.activeStreamUrl = '';
      }
    });

    await new Promise((resolve) => setTimeout(resolve, 1200));

    if (startupFailed || activeProcess.exitCode !== null) {
      await this.stopCamera();
      const reason = startupError || `exit code ${activeProcess.exitCode}`;
      throw new Error(`Camera bridge failed to start: ${reason}`);
    }
  }

  async stopCamera() {
    if (!this.process) {
      return;
    }

    const active = this.process;
    this.process = null;
    this.activeStreamUrl = '';

    await new Promise((resolve) => {
      active.once('exit', () => resolve());
      active.kill('SIGTERM');
      setTimeout(() => {
        if (!active.killed) {
          active.kill('SIGKILL');
        }
      }, 1000);
    });
  }

  isCameraRunning() {
    return !!(this.process && this.process.exitCode === null);
  }

  #resolveBackend() {
    if (this.cameraMode === 'userspace') {
      return 'linux-null-emulator';
    }
    if (this.cameraMode === 'auto') {
      return fs.existsSync(this.v4l2Device) ? 'linux-v4l2' : 'linux-null-emulator';
    }
    return 'linux-v4l2';
  }
}

export class MockCameraAdapter {
  constructor() {
    this.active = false;
  }

  setDeviceIdentity() {
  }

  getCameraDeviceName() {
    return 'Mock Phone Camera';
  }

  async startCamera() {
    this.active = true;
  }

  async stopCamera() {
    this.active = false;
  }

  isCameraRunning() {
    return this.active;
  }
}
