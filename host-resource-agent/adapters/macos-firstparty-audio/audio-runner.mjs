import { execFile, spawn } from 'node:child_process';
import { promisify } from 'node:util';
import { buildDeviceNames, normalizeDeviceIdentity } from '../common/device-name.mjs';
import { driverBundleExists } from './driver-probe.mjs';

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

async function listAudioToolboxDevices() {
  const { stderr } = await execFileAsync('ffmpeg', [
    '-hide_banner',
    '-f',
    'lavfi',
    '-i',
    'anullsrc=r=48000:cl=mono',
    '-t',
    '0.1',
    '-f',
    'audiotoolbox',
    '-list_devices',
    'true',
    '-y',
    '/dev/null',
  ]);

  const devices = [];
  const lines = stderr.split('\n');
  const pattern = /\[AudioToolbox @ .*] \[([0-9]+)\]\s+(.+?),/;
  for (const line of lines) {
    const match = line.match(pattern);
    if (!match) continue;
    devices.push({ index: Number.parseInt(match[1], 10), name: match[2].trim() });
  }
  return devices;
}

async function listAvfoundationAudioDevices() {
  let stderr = '';
  try {
    const result = await execFileAsync('ffmpeg', [
      '-hide_banner',
      '-f',
      'avfoundation',
      '-list_devices',
      'true',
      '-i',
      '',
    ]);
    stderr = result.stderr || '';
  } catch (error) {
    stderr = error?.stderr || '';
  }

  const devices = [];
  let inAudioSection = false;
  const lines = stderr.split('\n');
  const pattern = /\[AVFoundation indev @ .*] \[([0-9]+)\]\s+(.+)/;
  for (const line of lines) {
    if (line.includes('AVFoundation audio devices:')) {
      inAudioSection = true;
      continue;
    }
    if (line.includes('AVFoundation video devices:')) {
      inAudioSection = false;
      continue;
    }
    if (!inAudioSection) continue;

    const match = line.match(pattern);
    if (!match) continue;
    devices.push({
      index: Number.parseInt(match[1], 10),
      name: match[2].trim(),
    });
  }
  return devices;
}

function safeEnd(response) {
  try {
    response.end();
  } catch {
  }
}

export class MacOsFirstPartyAudioRunner {
  constructor({ enableSpeaker = false, streamUrl = '', outputDeviceName = 'PRCAudio 2ch' } = {}) {
    this.microphoneActive = false;
    this.speakerActive = false;
    this.enableSpeaker = enableSpeaker;
    this.streamUrl = streamUrl;
    this.outputDeviceName = outputDeviceName;
    this.activeStreamUrl = '';
    this.ffmpegProcess = null;
    this.deviceName = 'Phone';
    this.deviceId = 'default';
    this.speakerCaptureDeviceName = process.env.MACOS_SPEAKER_CAPTURE_DEVICE || this.outputDeviceName;
    this.speakerCaptureProcess = null;
    this.speakerClients = new Set();
    this.speakerSampleRate = Number(process.env.MACOS_SPEAKER_SAMPLE_RATE || 48000);
    this.speakerChannels = Number(process.env.MACOS_SPEAKER_CHANNELS || 2);
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

  getMicrophoneDeviceName() {
    return buildDeviceNames(this.deviceName, {
      microphoneTarget: this.outputDeviceName,
    }).microphone;
  }

  getSpeakerDeviceName() {
    if (!this.enableSpeaker) return null;
    return buildDeviceNames(this.deviceName, {
      speakerTarget: this.speakerCaptureDeviceName,
    }).speaker;
  }

  async startMicrophoneRoute() {
    if (!this.streamUrl) {
      throw new Error('cameraStreamUrl (RTSP) is required for microphone routing.');
    }
    if (!(await commandExists('ffmpeg'))) {
      throw new Error('ffmpeg is required for macOS microphone routing.');
    }
    if (this.microphoneActive && this.activeStreamUrl === this.streamUrl && this.ffmpegProcess) {
      return;
    }

    const prcDriverInstalled = await driverBundleExists();
    const devices = await listAudioToolboxDevices();
    const target = devices.find((device) => device.name.toLowerCase().includes(this.outputDeviceName.toLowerCase()));
    if (!target) {
      const available = devices.map((device) => device.name).join(', ') || 'none';
      const baseMessage = `Audio output device "${this.outputDeviceName}" not found. Available devices: ${available}`;
      if (!prcDriverInstalled) {
        throw new Error(
          `${baseMessage}. Install first-party driver with: host-resource-agent/macos-audio-driver/scripts/install-driver.sh`
        );
      }
      throw new Error(`${baseMessage}. Reinstall PRCAudio.driver and restart coreaudiod.`);
    }

    await this.stopMicrophoneRoute();
    await this.#startFfmpeg(target.index, this.streamUrl);
    this.activeStreamUrl = this.streamUrl;
    this.microphoneActive = true;
  }

  async stopMicrophoneRoute() {
    if (!this.ffmpegProcess) {
      this.microphoneActive = false;
      this.activeStreamUrl = '';
      return;
    }

    const active = this.ffmpegProcess;
    this.ffmpegProcess = null;
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
    this.microphoneActive = false;
    this.activeStreamUrl = '';
  }

  async startSpeakerRoute() {
    if (!this.enableSpeaker) {
      throw new Error('Speaker routing is not enabled on this host build.');
    }
    if (!(await commandExists('ffmpeg'))) {
      throw new Error('ffmpeg is required for macOS speaker routing.');
    }
    if (this.speakerActive && this.speakerCaptureProcess) {
      return;
    }

    const devices = await listAvfoundationAudioDevices();
    const target = devices.find((device) =>
      device.name.toLowerCase().includes(this.speakerCaptureDeviceName.toLowerCase())
    );
    if (!target) {
      const available = devices.map((device) => device.name).join(', ') || 'none';
      throw new Error(
        `Audio capture device "${this.speakerCaptureDeviceName}" not found for speaker route. Available devices: ${available}`
      );
    }

    await this.stopSpeakerRoute();
    await this.#startSpeakerCapture(target.index);
    this.speakerActive = true;
  }

  async stopSpeakerRoute() {
    if (this.speakerCaptureProcess) {
      const active = this.speakerCaptureProcess;
      this.speakerCaptureProcess = null;
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
    this.#closeSpeakerClients();
    this.speakerActive = false;
  }

  attachSpeakerClient(response) {
    if (!this.speakerActive || !this.speakerCaptureProcess) {
      throw new Error('Speaker route is not active. Enable speaker first.');
    }

    response.writeHead(200, {
      'Content-Type': 'application/octet-stream',
      'Cache-Control': 'no-store',
      Connection: 'keep-alive',
      'X-PCM-ENCODING': 's16le',
      'X-PCM-SAMPLE-RATE': String(this.speakerSampleRate),
      'X-PCM-CHANNELS': String(this.speakerChannels),
    });
    this.speakerClients.add(response);
    response.on('close', () => {
      this.speakerClients.delete(response);
    });
    response.on('error', () => {
      this.speakerClients.delete(response);
    });
    response.socket?.on('error', () => {
      this.speakerClients.delete(response);
      safeEnd(response);
    });
  }

  async stopAll() {
    await this.stopMicrophoneRoute();
    await this.stopSpeakerRoute();
  }

  isMicrophoneRunning() {
    return !!(this.ffmpegProcess && this.ffmpegProcess.exitCode === null);
  }

  isSpeakerRunning() {
    return !!(this.speakerCaptureProcess && this.speakerCaptureProcess.exitCode === null);
  }

  async #startFfmpeg(audioDeviceIndex, streamUrl) {
    const process = spawn('ffmpeg', [
      '-hide_banner',
      '-loglevel',
      'warning',
      '-nostdin',
      '-fflags',
      'nobuffer',
      '-flags',
      'low_delay',
      '-rtsp_transport',
      'tcp',
      '-i',
      streamUrl,
      '-vn',
      '-ac',
      '1',
      '-ar',
      '48000',
      '-f',
      'audiotoolbox',
      '-audio_device_index',
      String(audioDeviceIndex),
      'default',
    ], {
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    let startupError = null;
    process.stderr.on('data', (chunk) => {
      const text = chunk.toString();
      if (text.toLowerCase().includes('error')) {
        startupError = text.trim();
      }
    });

    process.on('exit', () => {
      this.ffmpegProcess = null;
      this.microphoneActive = false;
    });

    await sleep(700);
    if (startupError) {
      try {
        process.kill('SIGTERM');
      } catch {
      }
      throw new Error(`macOS microphone bridge failed: ${startupError}`);
    }

    this.ffmpegProcess = process;
  }

  async #startSpeakerCapture(audioDeviceIndex) {
    const channelLayout = this.speakerChannels <= 1 ? 'mono' : 'stereo';
    const filterCandidates = [
      `aresample=${this.speakerSampleRate}:resampler=soxr:osf=s16:ocl=${channelLayout}`,
      `aresample=${this.speakerSampleRate}:resampler=soxr:osf=s16`,
      `aresample=${this.speakerSampleRate}`,
    ];

    let process = null;
    let startupError = null;

    for (const filterExpr of filterCandidates) {
      const attempt = spawn('ffmpeg', [
        '-hide_banner',
        '-loglevel',
        'warning',
        '-nostdin',
        '-fflags',
        'nobuffer',
        '-flags',
        'low_delay',
        '-thread_queue_size',
        '1024',
        '-f',
        'avfoundation',
        '-i',
        `:${audioDeviceIndex}`,
        '-vn',
        '-af',
        filterExpr,
        '-ac',
        String(this.speakerChannels),
        '-ar',
        String(this.speakerSampleRate),
        '-acodec',
        'pcm_s16le',
        '-f',
        's16le',
        'pipe:1',
      ], {
        stdio: ['ignore', 'pipe', 'pipe'],
      });

      let attemptStartupError = null;
      attempt.stderr.on('data', (chunk) => {
        const text = chunk.toString();
        if (text.toLowerCase().includes('error')) {
          attemptStartupError = text.trim();
        }
      });

      await sleep(700);
      if (!attemptStartupError && attempt.exitCode === null) {
        process = attempt;
        startupError = null;
        break;
      }

      startupError = attemptStartupError || 'ffmpeg exited during startup';
      try {
        attempt.kill('SIGTERM');
      } catch {
      }
      await Promise.race([
        new Promise((resolve) => attempt.once('exit', () => resolve())),
        sleep(300),
      ]);
    }

    if (!process) {
      throw new Error(`macOS speaker capture failed: ${startupError}`);
    }

    process.stdout.on('data', (chunk) => {
      for (const client of this.speakerClients) {
        if (client.destroyed || client.writableEnded || client.socket?.destroyed) {
          this.speakerClients.delete(client);
          continue;
        }
        try {
          client.write(chunk);
        } catch {
          this.speakerClients.delete(client);
          safeEnd(client);
        }
      }
    });

    process.on('exit', () => {
      this.speakerCaptureProcess = null;
      this.speakerActive = false;
      this.#closeSpeakerClients();
    });

    this.speakerCaptureProcess = process;
  }

  #closeSpeakerClients() {
    for (const client of this.speakerClients) {
      safeEnd(client);
    }
    this.speakerClients.clear();
  }
}

export class MockMacAudioAdapter {
  constructor({ enableSpeaker = false } = {}) {
    this.microphoneActive = false;
    this.speakerActive = false;
    this.enableSpeaker = enableSpeaker;
  }

  setStreamUrl() {
  }

  setDeviceIdentity() {
  }

  getMicrophoneDeviceName() {
    return 'Mock Phone Mic';
  }

  getSpeakerDeviceName() {
    return this.enableSpeaker ? 'Mock Phone Speaker' : null;
  }

  async startMicrophoneRoute() {
    this.microphoneActive = true;
  }

  async stopMicrophoneRoute() {
    this.microphoneActive = false;
  }

  async startSpeakerRoute() {
    if (!this.enableSpeaker) {
      throw new Error('Speaker disabled in mock adapter.');
    }
    this.speakerActive = true;
  }

  attachSpeakerClient(response) {
    response.writeHead(200, {
      'Content-Type': 'application/octet-stream',
      'Cache-Control': 'no-store',
      'X-PCM-ENCODING': 's16le',
      'X-PCM-SAMPLE-RATE': '48000',
      'X-PCM-CHANNELS': '1',
    });
    response.end(Buffer.alloc(0));
  }

  async stopSpeakerRoute() {
    this.speakerActive = false;
  }

  async stopAll() {
    this.microphoneActive = false;
    this.speakerActive = false;
  }

  isMicrophoneRunning() {
    return this.microphoneActive;
  }

  isSpeakerRunning() {
    return this.speakerActive;
  }
}
