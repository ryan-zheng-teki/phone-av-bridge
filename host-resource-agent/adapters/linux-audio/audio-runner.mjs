import { execFile, spawn } from 'node:child_process';
import { promisify } from 'node:util';
import { buildDeviceNames, compactId, normalizeDeviceIdentity, slugify } from '../common/device-name.mjs';

const execFileAsync = promisify(execFile);

function safeEnd(response) {
  try {
    response.end();
  } catch {
  }
}

async function commandExists(command) {
  try {
    await execFileAsync('which', [command]);
    return true;
  } catch {
    return false;
  }
}

export class LinuxAudioRunner {
  constructor({ enableSpeaker = false, streamUrl = '' } = {}) {
    this.microphoneActive = false;
    this.speakerActive = false;
    this.enableSpeaker = enableSpeaker;
    this.streamUrl = streamUrl;
    this.activeStreamUrl = '';
    this.micFfmpegProcess = null;
    this.micSinkModuleId = null;
    this.deviceName = 'Phone';
    this.deviceId = 'default';
    this.micSinkName = 'phone_resource_companion_mic_sink_default';
    this.micSourceName = 'phone_resource_companion_mic_source_default';
    this.micSinkDescription = 'Phone_Mic_Output';
    this.micSourceDescription = 'Phone_Mic';
    this.activeRouteKey = '';
    this.speakerCaptureProcess = null;
    this.speakerClients = new Set();
    this.speakerSourceName = (process.env.LINUX_SPEAKER_CAPTURE_SOURCE || '').trim();
    this.speakerSampleRate = 48000;
    this.speakerChannels = 1;
    this.#rebuildRouteIdentity();
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
    this.#rebuildRouteIdentity();
  }

  getMicrophoneDeviceName() {
    const labels = buildDeviceNames(this.deviceName, {
      microphoneTarget: this.micSourceDescription.replace(/_/g, ' '),
    });
    return labels.microphone;
  }

  getSpeakerDeviceName() {
    if (!this.enableSpeaker) return null;
    const labels = buildDeviceNames(this.deviceName, {
      speakerTarget: this.speakerSourceName || 'Default monitor',
    });
    return labels.speaker;
  }

  async startMicrophoneRoute() {
    if (!this.streamUrl) {
      throw new Error('cameraStreamUrl (RTSP) is required for microphone routing.');
    }
    if (!(await commandExists('pactl'))) {
      throw new Error('pactl is required for Linux microphone routing.');
    }
    if (!(await commandExists('ffmpeg'))) {
      throw new Error('ffmpeg is required for Linux microphone routing.');
    }

    const routeKey = this.#routeKey();
    if (
      this.microphoneActive &&
      this.activeStreamUrl === this.streamUrl &&
      this.micFfmpegProcess &&
      this.activeRouteKey === routeKey
    ) {
      return;
    }

    await this.stopMicrophoneRoute();
    await this.#loadNullSink();
    await this.#startMicFfmpeg(this.streamUrl);

    this.activeStreamUrl = this.streamUrl;
    this.microphoneActive = true;
    this.activeRouteKey = routeKey;
  }

  async stopMicrophoneRoute() {
    if (this.micFfmpegProcess) {
      const active = this.micFfmpegProcess;
      this.micFfmpegProcess = null;
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

    if (this.micSinkModuleId !== null) {
      try {
        await execFileAsync('pactl', ['unload-module', String(this.micSinkModuleId)]);
      } catch {
      }
      this.micSinkModuleId = null;
    }

    this.activeStreamUrl = '';
    this.microphoneActive = false;
    this.activeRouteKey = '';
  }

  async startSpeakerRoute() {
    if (!this.enableSpeaker) {
      throw new Error('Speaker routing is not enabled on this host build.');
    }
    if (!(await commandExists('pactl'))) {
      throw new Error('pactl is required for Linux speaker routing.');
    }
    if (!(await commandExists('ffmpeg'))) {
      throw new Error('ffmpeg is required for Linux speaker routing.');
    }
    if (this.speakerActive && this.speakerCaptureProcess) {
      return;
    }

    await this.stopSpeakerRoute();
    const sourceName = await this.#resolveSpeakerSourceName();
    if (!sourceName) {
      throw new Error('No PulseAudio/PipeWire source available for speaker capture.');
    }
    await this.#startSpeakerCapture(sourceName);
    this.speakerSourceName = sourceName;
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
  }

  async stopAll() {
    await this.stopMicrophoneRoute();
    await this.stopSpeakerRoute();
  }

  isMicrophoneRunning() {
    return !!(this.micFfmpegProcess && this.micFfmpegProcess.exitCode === null);
  }

  isSpeakerRunning() {
    return !!(this.speakerCaptureProcess && this.speakerCaptureProcess.exitCode === null);
  }

  async #loadNullSink() {
    let stdout = '';
    try {
      ({ stdout } = await execFileAsync('pactl', [
        'load-module',
        'module-null-sink',
        `sink_name=${this.micSinkName}`,
        `source_name=${this.micSourceName}`,
        `sink_properties=device.description=${this.micSinkDescription}`,
        `source_properties=device.description=${this.micSourceDescription}`,
      ]));
    } catch (primaryError) {
      try {
        ({ stdout } = await execFileAsync('pactl', [
          'load-module',
          'module-null-sink',
          `sink_name=${this.micSinkName}`,
          `sink_properties=device.description=${this.micSinkDescription}`,
        ]));
        this.micSourceName = `${this.micSinkName}.monitor`;
      } catch {
        throw primaryError;
      }
    }
    const moduleId = Number.parseInt(stdout.trim(), 10);
    if (Number.isNaN(moduleId)) {
      throw new Error('Failed to initialize virtual microphone sink.');
    }
    this.micSinkModuleId = moduleId;
  }

  async #startMicFfmpeg(streamUrl) {
    const process = spawn('ffmpeg', [
      '-hide_banner',
      '-loglevel',
      'warning',
      '-rtsp_transport',
      'tcp',
      '-i',
      streamUrl,
      '-map',
      '0:a:0?',
      '-vn',
      '-ac',
      '1',
      '-ar',
      '48000',
      '-f',
      'pulse',
      this.micSinkName,
    ], {
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    process.on('exit', () => {
      this.micFfmpegProcess = null;
      this.microphoneActive = false;
    });
    await this.#awaitFfmpegStartup(process, 'Microphone bridge failed');

    this.micFfmpegProcess = process;
  }

  async #resolveSpeakerSourceName() {
    const override = (process.env.LINUX_SPEAKER_CAPTURE_SOURCE || '').trim();
    if (override) {
      return override;
    }

    try {
      const { stdout } = await execFileAsync('pactl', ['info']);
      const sinkLine = stdout
        .split('\n')
        .map((line) => line.trim())
        .find((line) => line.toLowerCase().startsWith('default sink:'));
      const defaultSink = sinkLine?.split(':').slice(1).join(':').trim();
      if (defaultSink) {
        return `${defaultSink}.monitor`;
      }
    } catch {
    }

    try {
      const { stdout } = await execFileAsync('pactl', ['list', 'short', 'sources']);
      const sources = stdout
        .split('\n')
        .map((line) => line.trim())
        .filter(Boolean)
        .map((line) => line.split('\t')[1])
        .filter(Boolean);
      const monitorSource = sources.find((source) => source.endsWith('.monitor'));
      return monitorSource || sources[0] || null;
    } catch {
      return null;
    }
  }

  async #startSpeakerCapture(sourceName) {
    const process = spawn('ffmpeg', [
      '-hide_banner',
      '-loglevel',
      'warning',
      '-f',
      'pulse',
      '-i',
      sourceName,
      '-ac',
      String(this.speakerChannels),
      '-ar',
      String(this.speakerSampleRate),
      '-f',
      's16le',
      'pipe:1',
    ], {
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    process.stdout.on('data', (chunk) => {
      for (const client of this.speakerClients) {
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
    await this.#awaitFfmpegStartup(process, 'Linux speaker capture failed');

    this.speakerCaptureProcess = process;
  }

  async #awaitFfmpegStartup(process, errorPrefix) {
    let exitedEarly = false;
    let spawnError = null;
    const stderrLines = [];

    process.stderr?.on('data', (chunk) => {
      const text = chunk.toString();
      if (!text) return;
      stderrLines.push(text.trim());
      if (stderrLines.length > 12) {
        stderrLines.shift();
      }
    });

    process.on('error', (error) => {
      spawnError = error;
    });

    process.once('exit', () => {
      exitedEarly = true;
    });

    await new Promise((resolve) => setTimeout(resolve, 700));

    if (spawnError || exitedEarly || process.exitCode !== null) {
      const stderrTail = stderrLines.filter(Boolean).join('\n').trim();
      const detail = spawnError?.message || stderrTail || `ffmpeg exited early (code=${process.exitCode})`;
      try {
        process.kill('SIGTERM');
      } catch {
      }
      throw new Error(`${errorPrefix}: ${detail}`);
    }
  }

  #closeSpeakerClients() {
    for (const client of this.speakerClients) {
      safeEnd(client);
    }
    this.speakerClients.clear();
  }

  #routeKey() {
    return `${this.micSinkName}:${this.micSourceName}`;
  }

  #rebuildRouteIdentity() {
    const nameSlug = slugify(this.deviceName, 'phone');
    const idSlug = compactId(this.deviceId, 'default');
    this.micSinkName = `phone_resource_companion_mic_sink_${nameSlug}_${idSlug}`.slice(0, 63);
    this.micSourceName = `phone_resource_companion_mic_src_${nameSlug}_${idSlug}`.slice(0, 63);
    const baseDescription = `${this.deviceName.slice(0, 32)} Mic`;
    this.micSinkDescription = `${baseDescription} Output`.replace(/\s+/g, '_');
    this.micSourceDescription = baseDescription.replace(/\s+/g, '_');
  }
}

export class MockAudioAdapter {
  constructor({ enableSpeaker = true } = {}) {
    this.microphoneActive = false;
    this.speakerActive = false;
    this.enableSpeaker = enableSpeaker;
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
