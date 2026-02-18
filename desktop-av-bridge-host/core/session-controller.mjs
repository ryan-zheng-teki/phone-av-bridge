import { EventEmitter } from 'node:events';

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function defaultResources() {
  return {
    camera: false,
    microphone: false,
    speaker: false,
  };
}

function normalizeCameraLens(value) {
  if (typeof value !== 'string') {
    return null;
  }
  const normalized = value.trim().toLowerCase();
  if (normalized === 'front' || normalized === 'back') {
    return normalized;
  }
  return null;
}

function normalizeCameraOrientationMode(value) {
  if (typeof value !== 'string') {
    return null;
  }
  const normalized = value.trim().toLowerCase();
  if (normalized === 'auto' || normalized === 'portrait_lock' || normalized === 'landscape_lock') {
    return normalized;
  }
  return null;
}

function normalizeText(value, maxLength = 64) {
  if (typeof value !== 'string') {
    return null;
  }
  const trimmed = value.trim();
  if (!trimmed) {
    return null;
  }
  return trimmed.slice(0, maxLength);
}

function normalizeIssueMessage(resource, rawMessage) {
  const text = typeof rawMessage === 'string' ? rawMessage.trim() : '';
  const normalized = text.toLowerCase();

  if (resource === 'camera') {
    if (normalized.includes('camera extension') || normalized.includes('frame server')) {
      return 'Camera bridge is unavailable. Open Phone AV Bridge Camera and ensure Camera Extension approval is complete.';
    }
    if (normalized.includes('stream') || normalized.includes('rtsp')) {
      return 'Camera stream is unreachable from host. Keep the phone app open and camera enabled.';
    }
    return 'Camera route could not be started. Check host preflight and retry.';
  }

  if (resource === 'microphone') {
    if (normalized.includes('not found') && normalized.includes('audio')) {
      return 'Microphone route target is missing. Verify Phone AV Bridge Audio (macOS) or virtual mic sink (Linux).';
    }
    if (normalized.includes('ffmpeg')) {
      return 'Microphone route failed to start because ffmpeg is unavailable or failed.';
    }
    return 'Microphone route could not be started. Check host preflight and retry.';
  }

  if (resource === 'speaker') {
    if (normalized.includes('not found') && normalized.includes('capture')) {
      return 'Speaker capture device is unavailable. Select a valid host output-capture source and retry.';
    }
    if (normalized.includes('enable speaker first')) {
      return 'Speaker route is not active yet. Enable speaker route and retry.';
    }
    return 'Speaker route could not be started. Check host preflight and retry.';
  }

  return 'Resource route failed. Check host preflight and retry.';
}

export class SessionController extends EventEmitter {
  constructor({ cameraAdapter, audioAdapter, capabilities } = {}) {
    super();
    this.cameraAdapter = cameraAdapter;
    this.audioAdapter = audioAdapter;
    this.capabilities = {
      camera: capabilities?.camera ?? true,
      microphone: capabilities?.microphone ?? true,
      speaker: capabilities?.speaker ?? true,
    };

    this.state = {
      paired: false,
      pairCode: null,
      connectionState: 'not_paired',
      hostStatus: 'Not Paired',
      capabilities: {
        camera: this.capabilities.camera,
        microphone: this.capabilities.microphone,
        speaker: this.capabilities.speaker,
      },
      phone: {
        deviceName: null,
        deviceId: null,
      },
      phoneCamera: {
        lens: 'back',
        orientationMode: 'auto',
      },
      routeHints: {
        camera: null,
        microphone: null,
        speaker: null,
      },
      cameraStreamUrl: null,
      resources: defaultResources(),
      issues: [],
      updatedAt: new Date().toISOString(),
    };
    this.applyQueue = Promise.resolve();

    this.#refreshRouteHints();
  }

  getStatus() {
    return clone(this.state);
  }

  attachSpeakerStream(response) {
    if (!this.state.paired) {
      throw new Error('Host is not paired. Pair first.');
    }
    if (!this.state.resources.speaker) {
      throw new Error('Speaker route is not active. Enable speaker first.');
    }
    if (!this.audioAdapter?.attachSpeakerClient) {
      throw new Error('Speaker streaming is unavailable on this host.');
    }
    this.audioAdapter.attachSpeakerClient(response);
  }

  async pairHost(pairCode, metadata = {}) {
    if (!pairCode || typeof pairCode !== 'string' || pairCode.trim().length < 4) {
      throw new Error('Pair code must contain at least 4 characters.');
    }

    this.#updateDeviceMetadata(metadata);
    this.state.paired = true;
    this.state.pairCode = pairCode.trim();
    this.state.connectionState = 'paired';
    this.state.hostStatus = 'Paired';
    this.#refreshRouteHints();
    this.state.updatedAt = new Date().toISOString();
    this.emit('status', this.getStatus());
    return this.getStatus();
  }

  async unpairHost() {
    await this.#disableAllResources();
    this.state.paired = false;
    this.state.pairCode = null;
    this.state.cameraStreamUrl = null;
    this.state.connectionState = 'not_paired';
    this.state.hostStatus = 'Not Paired';
    this.state.issues = [];
    this.#refreshRouteHints();
    this.state.updatedAt = new Date().toISOString();
    this.emit('status', this.getStatus());
    return this.getStatus();
  }

  notePhonePresence(metadata = {}) {
    const changed = this.#updateDeviceMetadata(metadata);
    if (!changed) {
      return this.getStatus();
    }

    if (!this.state.paired) {
      this.state.connectionState = 'not_paired';
      this.state.hostStatus = 'Not Paired';
    }
    this.state.updatedAt = new Date().toISOString();
    this.emit('status', this.getStatus());
    return this.getStatus();
  }

  async applyResourceState(diff = {}) {
    this.applyQueue = this.applyQueue
      .then(() => this.#applyResourceStateSerial(diff))
      .catch((error) => {
        throw error;
      });
    return this.applyQueue;
  }

  async #applyResourceStateSerial(diff = {}) {
    if (!this.state.paired) {
      throw new Error('Host is not paired. Pair first.');
    }

    const next = {
      ...this.state.resources,
      ...diff,
    };
    const nextLens = normalizeCameraLens(diff.cameraLens) || this.state.phoneCamera.lens;
    const nextOrientationMode = normalizeCameraOrientationMode(diff.cameraOrientationMode) || this.state.phoneCamera.orientationMode;
    const previousResources = { ...this.state.resources };
    const previousStreamUrl = this.state.cameraStreamUrl;
    const streamUrl = typeof diff.cameraStreamUrl === 'string' ? diff.cameraStreamUrl.trim() : this.state.cameraStreamUrl;
    const mediaStreamRequested = next.camera || next.microphone;
    const nextStreamUrl = !mediaStreamRequested ? null : streamUrl || this.state.cameraStreamUrl;
    const metadataChanged = this.#updateDeviceMetadata(diff);
    this.state.phoneCamera = {
      lens: nextLens,
      orientationMode: nextOrientationMode,
    };

    const resourcesUnchanged = (
      previousResources.camera === next.camera
      && previousResources.microphone === next.microphone
      && previousResources.speaker === next.speaker
    );
    const streamUnchanged = (previousStreamUrl || null) === (nextStreamUrl || null);
    const runtimeHealthy = this.#runtimeHealthy(next);
    if (resourcesUnchanged && streamUnchanged && !metadataChanged && this.state.issues.length === 0 && runtimeHealthy) {
      this.state.connectionState = 'paired';
      this.state.hostStatus = next.camera || next.microphone || next.speaker ? 'Resource Active' : 'Paired';
      this.state.updatedAt = new Date().toISOString();
      this.emit('status', this.getStatus());
      return this.getStatus();
    }

    this.state.cameraStreamUrl = nextStreamUrl;

    this.state.issues = this.state.issues.filter((issue) => !['camera', 'microphone', 'speaker'].includes(issue.resource));

    await this.#applyCamera(next.camera, this.state.cameraStreamUrl);
    await this.#applyMicrophone(next.microphone);
    await this.#applySpeaker(next.speaker);

    this.state.resources = {
      camera: this.state.resources.camera,
      microphone: this.state.resources.microphone,
      speaker: this.state.resources.speaker,
    };

    const anyEnabled = this.state.resources.camera || this.state.resources.microphone || this.state.resources.speaker;
    const hasIssues = this.state.issues.length > 0;
    this.state.connectionState = hasIssues ? 'needs_attention' : 'paired';
    this.state.hostStatus = hasIssues ? 'Needs Attention' : anyEnabled ? 'Resource Active' : 'Paired';
    this.#refreshRouteHints();
    this.state.updatedAt = new Date().toISOString();
    this.emit('status', this.getStatus());
    return this.getStatus();
  }

  async #disableAllResources() {
    if (this.state.resources.camera && this.cameraAdapter?.stopCamera) {
      await this.cameraAdapter.stopCamera();
    }
    if ((this.state.resources.microphone || this.state.resources.speaker) && this.audioAdapter?.stopAll) {
      await this.audioAdapter.stopAll();
    }
    this.state.resources = defaultResources();
    this.state.cameraStreamUrl = null;
  }

  async #applyCamera(enabled, streamUrl) {
    if (!enabled) {
      if (this.state.resources.camera && this.cameraAdapter?.stopCamera) {
        await this.cameraAdapter.stopCamera();
      }
      this.state.resources.camera = false;
      return;
    }

    if (!this.capabilities.camera) {
      this.state.resources.camera = false;
      this.#pushIssue('camera', 'Camera capability unavailable on this host.');
      return;
    }

    try {
      if (streamUrl && this.cameraAdapter?.setStreamUrl) {
        this.cameraAdapter.setStreamUrl(streamUrl);
      }
      if (this.cameraAdapter?.startCamera) {
        await this.cameraAdapter.startCamera();
      }
      this.state.resources.camera = true;
    } catch (error) {
      this.state.resources.camera = false;
      this.#pushIssue('camera', error?.message || 'Camera adapter failed.');
    }
  }

  async #applyMicrophone(enabled) {
    if (!enabled) {
      if (this.state.resources.microphone && this.audioAdapter?.stopMicrophoneRoute) {
        await this.audioAdapter.stopMicrophoneRoute();
      }
      this.state.resources.microphone = false;
      return;
    }

    if (!this.capabilities.microphone) {
      this.state.resources.microphone = false;
      this.#pushIssue('microphone', 'Microphone capability unavailable on this host.');
      return;
    }

    try {
      if (this.state.cameraStreamUrl && this.audioAdapter?.setStreamUrl) {
        this.audioAdapter.setStreamUrl(this.state.cameraStreamUrl);
      }
      if (this.audioAdapter?.startMicrophoneRoute) {
        await this.audioAdapter.startMicrophoneRoute();
      }
      this.state.resources.microphone = true;
    } catch (error) {
      this.state.resources.microphone = false;
      this.#pushIssue('microphone', error?.message || 'Microphone adapter failed.');
    }
  }

  async #applySpeaker(enabled) {
    if (!enabled) {
      if (this.state.resources.speaker && this.audioAdapter?.stopSpeakerRoute) {
        await this.audioAdapter.stopSpeakerRoute();
      }
      this.state.resources.speaker = false;
      return;
    }

    if (!this.capabilities.speaker) {
      this.state.resources.speaker = false;
      this.#pushIssue('speaker', 'Speaker capability unavailable on this host.');
      return;
    }

    try {
      if (this.audioAdapter?.startSpeakerRoute) {
        await this.audioAdapter.startSpeakerRoute();
      }
      this.state.resources.speaker = true;
    } catch (error) {
      this.state.resources.speaker = false;
      this.#pushIssue('speaker', error?.message || 'Speaker adapter failed.');
    }
  }

  #pushIssue(resource, rawMessage) {
    this.state.issues.push({
      resource,
      message: normalizeIssueMessage(resource, rawMessage),
      detail: typeof rawMessage === 'string' ? rawMessage.trim() : 'Unknown adapter failure.',
    });
  }

  #runtimeHealthy(next) {
    const cameraHealthy = !next.camera || this.#probeAdapterHealth(() => this.cameraAdapter?.isCameraRunning?.());
    const microphoneHealthy = !next.microphone || this.#probeAdapterHealth(() => this.audioAdapter?.isMicrophoneRunning?.());
    const speakerHealthy = !next.speaker || this.#probeAdapterHealth(() => this.audioAdapter?.isSpeakerRunning?.());
    return cameraHealthy && microphoneHealthy && speakerHealthy;
  }

  #probeAdapterHealth(healthProbe) {
    try {
      const result = healthProbe();
      if (typeof result === 'boolean') {
        return result;
      }
      return true;
    } catch {
      return false;
    }
  }

  #updateDeviceMetadata(metadata) {
    const deviceName = normalizeText(metadata?.deviceName, 80);
    const deviceId = normalizeText(metadata?.deviceId, 128);
    if (!deviceName && !deviceId) {
      return false;
    }

    let changed = false;
    if (deviceName) {
      changed = changed || this.state.phone.deviceName !== deviceName;
      this.state.phone.deviceName = deviceName;
    }
    if (deviceId) {
      changed = changed || this.state.phone.deviceId !== deviceId;
      this.state.phone.deviceId = deviceId;
    }

    const identity = {
      deviceName: this.state.phone.deviceName,
      deviceId: this.state.phone.deviceId,
    };
    this.cameraAdapter?.setDeviceIdentity?.(identity);
    this.audioAdapter?.setDeviceIdentity?.(identity);
    return changed;
  }

  #refreshRouteHints() {
    this.state.routeHints = {
      camera: this.cameraAdapter?.getCameraDeviceName?.() ?? null,
      microphone: this.audioAdapter?.getMicrophoneDeviceName?.() ?? null,
      speaker: this.audioAdapter?.getSpeakerDeviceName?.() ?? null,
    };
  }
}
