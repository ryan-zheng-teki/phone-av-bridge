import { execFile, spawn } from 'node:child_process';
import { promisify } from 'node:util';
import { buildDeviceNames, compactId, normalizeDeviceIdentity, slugify } from '../common/device-name.mjs';

const execFileAsync = promisify(execFile);
const DEFAULT_LINUX_MIC_PULSE_LATENCY_MSEC = '30';
const LOW_LATENCY_DISABLED_VALUES = new Set(['0', 'false', 'off', 'no']);

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

function normalizeSourceName(sourceName) {
  return (sourceName || '').trim();
}

function parseDefaultSinkNameFromPactlInfo(stdout = '') {
  const sinkLine = stdout
    .split('\n')
    .map((line) => line.trim())
    .find((line) => line.toLowerCase().startsWith('default sink:'));
  return sinkLine?.split(':').slice(1).join(':').trim() || '';
}

function parseSourcesFromPactlList(stdout = '') {
  return stdout
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => line.split('\t')[1])
    .map((value) => value?.trim())
    .filter(Boolean);
}

export function isLinuxMicLowLatencyEnabled(rawValue = process.env.LINUX_MIC_LOW_LATENCY) {
  const normalized = String(rawValue ?? '').trim().toLowerCase();
  if (!normalized) return true;
  return !LOW_LATENCY_DISABLED_VALUES.has(normalized);
}

export function resolveLinuxMicPulseLatencyMsec(rawValue = process.env.LINUX_MIC_PULSE_LATENCY_MSEC) {
  const normalized = String(rawValue ?? '').trim();
  if (!normalized) return DEFAULT_LINUX_MIC_PULSE_LATENCY_MSEC;
  const parsed = Number.parseInt(normalized, 10);
  if (!Number.isFinite(parsed) || parsed < 10 || parsed > 500) {
    return DEFAULT_LINUX_MIC_PULSE_LATENCY_MSEC;
  }
  return String(parsed);
}

export function buildLinuxMicFfmpegArgs(streamUrl, { lowLatency = true, rtspTransport = 'tcp' } = {}) {
  const transport = String(rtspTransport || '').trim() || 'tcp';
  const args = [
    '-hide_banner',
    '-loglevel',
    'warning',
    '-rtsp_transport',
    transport,
  ];

  if (lowLatency) {
    args.push(
      '-fflags', 'nobuffer',
      '-flags', 'low_delay',
      '-analyzeduration', '0',
      '-probesize', '32k',
      '-flush_packets', '1',
    );
  }

  args.push(
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
    'phone-av-bridge-mic',
  );
  return args;
}

function isBridgeMicrophoneSource(sourceName, { micSinkName, micSourceName }) {
  const source = normalizeSourceName(sourceName);
  if (!source) return false;
  if (source === micSourceName) return true;
  if (source === `${micSinkName}.monitor`) return true;
  return source.startsWith('phone_av_bridge_mic_sink_') ||
    source.startsWith('phone_av_bridge_mic_src_') ||
    source.startsWith('phone_av_bridge_mic_input_');
}

export function pickLinuxSpeakerCaptureSource({
  override = '',
  defaultSinkName = '',
  sources = [],
  micSinkName = '',
  micSourceName = '',
} = {}) {
  const overrideSource = normalizeSourceName(override);
  if (overrideSource) {
    return overrideSource;
  }

  const availableSources = [...new Set(sources.map((source) => normalizeSourceName(source)).filter(Boolean))];
  const allowSource = (sourceName) => !isBridgeMicrophoneSource(sourceName, { micSinkName, micSourceName });

  const defaultMonitorSource = defaultSinkName ? `${defaultSinkName}.monitor` : '';
  if (defaultMonitorSource && allowSource(defaultMonitorSource)) {
    if (!availableSources.length || availableSources.includes(defaultMonitorSource)) {
      return defaultMonitorSource;
    }
  }

  const safeMonitorSource = availableSources.find((sourceName) => sourceName.endsWith('.monitor') && allowSource(sourceName));
  if (safeMonitorSource) {
    return safeMonitorSource;
  }

  const safeFallbackSource = availableSources.find((sourceName) => allowSource(sourceName));
  return safeFallbackSource || null;
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
    this.micSinkName = 'phone_av_bridge_mic_sink_default';
    this.micSourceName = 'phone_av_bridge_mic_source_default';
    this.micInputSourceName = 'phone_av_bridge_mic_input_default';
    this.micSinkDescription = 'PhoneAVBridgeMic-phone-default';
    this.micSourceDescription = 'PhoneAVBridgeMicSource-phone-default';
    this.micInputSourceDescription = 'PhoneAVBridgeMicInput-phone-default';
    this.micSelectionTarget = 'PhoneAVBridgeMicInput-phone-default';
    this.activeRouteKey = '';
    this.speakerCaptureProcess = null;
    this.speakerClients = new Set();
    this.speakerSourceName = (process.env.LINUX_SPEAKER_CAPTURE_SOURCE || '').trim();
    this.speakerSampleRate = 48000;
    this.speakerChannels = 1;
    this.micInputModuleId = null;
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
      microphoneTarget: this.micSelectionTarget,
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
    await this.#cleanupStaleMicrophoneModules();
    await this.#loadNullSink();
    await this.#ensureVirtualMicrophoneSource();
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
    if (this.micInputModuleId !== null) {
      try {
        await execFileAsync('pactl', ['unload-module', String(this.micInputModuleId)]);
      } catch {
      }
      this.micInputModuleId = null;
    }
    await this.#cleanupStaleMicrophoneModules();

    this.activeStreamUrl = '';
    this.microphoneActive = false;
    this.activeRouteKey = '';
    this.micSelectionTarget = this.micInputSourceDescription;
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
    const lowLatencyEnabled = isLinuxMicLowLatencyEnabled();
    const pulseLatencyMsec = resolveLinuxMicPulseLatencyMsec();
    let process = this.#spawnMicFfmpegProcess(streamUrl, {
      lowLatency: lowLatencyEnabled,
      pulseLatencyMsec,
    });

    process.on('exit', () => {
      this.micFfmpegProcess = null;
      this.microphoneActive = false;
    });

    try {
      await this.#awaitFfmpegStartup(process, 'Microphone bridge failed');
    } catch (error) {
      if (!lowLatencyEnabled) {
        throw error;
      }
      try {
        process.kill('SIGTERM');
      } catch {
      }
      process = this.#spawnMicFfmpegProcess(streamUrl, {
        lowLatency: false,
        pulseLatencyMsec,
      });
      process.on('exit', () => {
        this.micFfmpegProcess = null;
        this.microphoneActive = false;
      });
      await this.#awaitFfmpegStartup(process, 'Microphone bridge failed');
    }

    const routed = await this.#moveSinkInputToBridgeSink(process.pid, this.micSinkName);
    if (!routed) {
      try {
        process.kill('SIGTERM');
      } catch {
      }
      throw new Error(`Microphone bridge failed: could not route ffmpeg sink-input to ${this.micSinkName}.`);
    }

    this.micFfmpegProcess = process;
  }

  #spawnMicFfmpegProcess(streamUrl, { lowLatency = true, pulseLatencyMsec = DEFAULT_LINUX_MIC_PULSE_LATENCY_MSEC } = {}) {
    const rtspTransport = (process.env.LINUX_MIC_RTSP_TRANSPORT || 'tcp').trim() || 'tcp';
    const args = buildLinuxMicFfmpegArgs(streamUrl, {
      lowLatency,
      rtspTransport,
    });
    return spawn('ffmpeg', args, {
      stdio: ['ignore', 'pipe', 'pipe'],
      env: {
        ...process.env,
        PULSE_LATENCY_MSEC: String(pulseLatencyMsec),
      },
    });
  }

  async #moveSinkInputToBridgeSink(processId, sinkName) {
    if (!Number.isInteger(processId) || processId <= 0 || !sinkName) {
      return false;
    }

    const deadline = Date.now() + 4000;
    while (Date.now() < deadline) {
      const sinkInputId = await this.#findSinkInputIdByProcessId(processId);
      if (sinkInputId !== null) {
        try {
          await execFileAsync('pactl', ['move-sink-input', String(sinkInputId), sinkName]);
          return true;
        } catch {
          return false;
        }
      }
      await new Promise((resolve) => setTimeout(resolve, 120));
    }
    return false;
  }

  async #findSinkInputIdByProcessId(processId) {
    try {
      const { stdout } = await execFileAsync('pactl', ['list', 'sink-inputs']);
      const blocks = stdout.split(/\n\s*\n/).map((block) => block.trim()).filter(Boolean);
      for (const block of blocks) {
        const idMatch = block.match(/#(\d+)/);
        const pidMatch = block.match(/application\.process\.id = "(\d+)"/);
        if (!idMatch || !pidMatch) {
          continue;
        }
        if (Number.parseInt(pidMatch[1], 10) !== processId) {
          continue;
        }
        const sinkInputId = Number.parseInt(idMatch[1], 10);
        if (!Number.isNaN(sinkInputId)) {
          return sinkInputId;
        }
      }
      return null;
    } catch {
      return null;
    }
  }

  async #ensureVirtualMicrophoneSource() {
    this.micSelectionTarget = this.micInputSourceDescription;
    let stdout = '';
    try {
      await this.#unloadModulesByArgs([
        `source_name=${this.micInputSourceName}`,
      ]);
      ({ stdout } = await execFileAsync('pactl', [
        'load-module',
        'module-remap-source',
        `master=${this.micSinkName}.monitor`,
        `source_name=${this.micInputSourceName}`,
        `source_properties=device.description=${this.micInputSourceDescription}`,
      ]));
    } catch (error) {
      this.micInputModuleId = null;
      throw new Error(`Failed to create Linux virtual microphone source (${this.micInputSourceName}): ${error.message}`);
    }

    const moduleId = Number.parseInt(stdout.trim(), 10);
    if (Number.isNaN(moduleId)) {
      this.micInputModuleId = null;
      throw new Error(`Failed to create Linux virtual microphone source (${this.micInputSourceName}): invalid module id.`);
    }
    this.micInputModuleId = moduleId;
  }

  async #cleanupStaleMicrophoneModules() {
    await this.#unloadModulesByArgs([
      `source_name=${this.micInputSourceName}`,
    ]);
    await this.#unloadModulesByArgs([
      `sink_name=${this.micSinkName}`,
    ]);
  }

  async #unloadModulesByArgs(requiredFragments = []) {
    if (!requiredFragments.length) {
      return;
    }
    try {
      const { stdout } = await execFileAsync('pactl', ['list', 'short', 'modules']);
      const moduleIds = stdout
        .split('\n')
        .map((line) => line.trim())
        .filter(Boolean)
        .map((line) => line.split('\t'))
        .filter((parts) => parts.length >= 2)
        .filter((parts) => {
          const args = parts.slice(2).join('\t');
          return requiredFragments.every((fragment) => args.includes(fragment));
        })
        .map((parts) => Number.parseInt(parts[0], 10))
        .filter((id) => Number.isInteger(id));

      for (const moduleId of moduleIds.sort((a, b) => b - a)) {
        try {
          await execFileAsync('pactl', ['unload-module', String(moduleId)]);
        } catch {
        }
      }
    } catch {
    }
  }

  async #resolveSpeakerSourceName() {
    const override = (process.env.LINUX_SPEAKER_CAPTURE_SOURCE || '').trim();
    let defaultSinkName = '';
    try {
      const { stdout } = await execFileAsync('pactl', ['info']);
      defaultSinkName = parseDefaultSinkNameFromPactlInfo(stdout);
    } catch {
    }

    let sources = [];
    try {
      const { stdout } = await execFileAsync('pactl', ['list', 'short', 'sources']);
      sources = parseSourcesFromPactlList(stdout);
    } catch {
    }

    return pickLinuxSpeakerCaptureSource({
      override,
      defaultSinkName,
      sources,
      micSinkName: this.micSinkName,
      micSourceName: this.micSourceName,
    });
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
    const nameToken = nameSlug.replace(/_/g, '-').slice(0, 24) || 'phone';
    const idToken = idSlug.slice(-6) || 'default';
    this.micSinkName = `phone_av_bridge_mic_sink_${nameSlug}_${idSlug}`.slice(0, 63);
    this.micSourceName = `phone_av_bridge_mic_src_${nameSlug}_${idSlug}`.slice(0, 63);
    this.micInputSourceName = `phone_av_bridge_mic_input_${nameSlug}_${idSlug}`.slice(0, 63);
    this.micSinkDescription = `PhoneAVBridgeMic-${nameToken}-${idToken}`;
    this.micSourceDescription = `PhoneAVBridgeMicSource-${nameToken}-${idToken}`;
    this.micInputSourceDescription = `PhoneAVBridgeMicInput-${nameToken}-${idToken}`;
    this.micSelectionTarget = this.micInputSourceDescription;
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
