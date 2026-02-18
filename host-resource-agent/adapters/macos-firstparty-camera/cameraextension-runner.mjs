import net from 'node:net';
import { execFile, spawn } from 'node:child_process';
import { promisify } from 'node:util';
import { buildDeviceNames, normalizeDeviceIdentity } from '../common/device-name.mjs';

const execFileAsync = promisify(execFile);

async function commandExists(command) {
  try {
    await execFileAsync('which', [command]);
    return true;
  } catch {
    return false;
  }
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function appExists(appPath) {
  if (!appPath) {
    return false;
  }
  try {
    await execFileAsync('test', ['-d', appPath]);
    return true;
  } catch {
    return false;
  }
}

async function probeTcp(host, port, timeoutMs = 700) {
  return new Promise((resolve) => {
    let done = false;
    const socket = net.createConnection({ host, port: Number(port) });
    const finalize = (result) => {
      if (done) {
        return;
      }
      done = true;
      socket.destroy();
      resolve(result);
    };

    socket.setTimeout(timeoutMs);
    socket.once('connect', () => finalize(true));
    socket.once('timeout', () => finalize(false));
    socket.once('error', () => finalize(false));
  });
}

export class MacOsCameraExtensionRunner {
  constructor(options = {}) {
    this.streamUrl = options.streamUrl ?? process.env.STREAM_SOURCE_URL ?? '';
    this.width = Number(options.width ?? process.env.MACOS_CAMERA_WIDTH ?? 1280);
    this.height = Number(options.height ?? process.env.MACOS_CAMERA_HEIGHT ?? 720);
    this.fps = Number(options.fps ?? process.env.MACOS_CAMERA_FPS ?? 30);
    this.frameHost = options.frameHost ?? process.env.MACOS_CAMERA_FRAME_HOST ?? '127.0.0.1';
    this.framePort = Number(options.framePort ?? process.env.MACOS_CAMERA_FRAME_PORT ?? 39501);
    this.hostAppPath = options.hostAppPath ?? process.env.MACOS_CAMERA_EXTENSION_APP ?? '';
    this.process = null;
    this.active = false;
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
    return buildDeviceNames(this.deviceName, {
      cameraTarget: 'Phone Resource Companion Camera',
    }).camera;
  }

  async startCamera() {
    if (!this.streamUrl) {
      throw new Error('cameraStreamUrl is required for macOS camera routing.');
    }
    if (!(await commandExists('ffmpeg'))) {
      throw new Error('ffmpeg is required for macOS camera routing.');
    }

    if (this.active && this.activeStreamUrl === this.streamUrl && this.process) {
      return;
    }

    await this.stopCamera();
    await this.#ensureFrameServer();
    await this.#startFfmpegPipe();

    this.active = true;
    this.activeStreamUrl = this.streamUrl;
  }

  async stopCamera() {
    if (!this.process) {
      this.active = false;
      this.activeStreamUrl = '';
      return;
    }

    const active = this.process;
    this.process = null;
    this.active = false;
    this.activeStreamUrl = '';

    await new Promise((resolve) => {
      active.once('exit', () => resolve());
      active.kill('SIGTERM');
      setTimeout(() => {
        try {
          active.kill('SIGKILL');
        } catch {
        }
      }, 1000);
    });
  }

  isCameraRunning() {
    return !!(this.process && this.process.exitCode === null);
  }

  async #ensureFrameServer() {
    if (await probeTcp(this.frameHost, this.framePort)) {
      return;
    }

    await this.#launchHostApp();
    for (let attempt = 0; attempt < 24; attempt += 1) {
      if (await probeTcp(this.frameHost, this.framePort)) {
        return;
      }
      await sleep(250);
    }
    throw new Error(
      `PRCCamera frame server is not reachable at tcp://${this.frameHost}:${this.framePort}. ` +
      'Open PRCCamera and approve Camera Extension in System Settings.'
    );
  }

  async #launchHostApp() {
    const candidates = [
      this.hostAppPath.trim(),
      '/Applications/PRCCamera.app',
      `${process.env.HOME || ''}/Applications/PRCCamera.app`,
    ].filter(Boolean);

    for (const candidate of candidates) {
      if (!(await appExists(candidate))) {
        continue;
      }
      try {
        await execFileAsync('open', ['-a', candidate]);
        return;
      } catch {
      }
    }
  }

  async #startFfmpegPipe() {
    const ffmpegProcess = spawn('ffmpeg', [
      '-hide_banner',
      '-loglevel',
      'warning',
      '-rtsp_transport',
      'tcp',
      '-i',
      this.streamUrl,
      '-an',
      '-vf',
      `scale=${this.width}:${this.height},fps=${this.fps},format=bgra`,
      '-pix_fmt',
      'bgra',
      '-f',
      'rawvideo',
      `tcp://${this.frameHost}:${this.framePort}`,
    ], {
      stdio: ['ignore', 'ignore', 'pipe'],
    });

    let startupError = '';
    ffmpegProcess.stderr.on('data', (chunk) => {
      const text = chunk.toString();
      if (text.toLowerCase().includes('error')) {
        startupError = text.trim();
      }
    });

    ffmpegProcess.on('exit', () => {
      if (this.process === ffmpegProcess) {
        this.process = null;
        this.active = false;
        this.activeStreamUrl = '';
      }
    });

    await sleep(1200);
    if (startupError || ffmpegProcess.exitCode !== null) {
      try {
        ffmpegProcess.kill('SIGTERM');
      } catch {
      }
      const reason = startupError || `exit code ${ffmpegProcess.exitCode}`;
      throw new Error(`macOS camera extension bridge failed: ${reason}`);
    }

    this.process = ffmpegProcess;
  }
}

export class MockMacCameraAdapter {
  constructor() {
    this.active = false;
  }

  setDeviceIdentity() {
  }

  getCameraDeviceName() {
    return 'Mock Phone Camera';
  }

  setStreamUrl() {
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
