function clampText(value, maxLength, fallback) {
  if (typeof value !== 'string') {
    return fallback;
  }
  const trimmed = value.trim();
  if (!trimmed) {
    return fallback;
  }
  return trimmed.slice(0, maxLength);
}

export function normalizeDeviceIdentity(identity = {}, current = {}) {
  const deviceName = clampText(identity.deviceName, 48, current.deviceName || 'Phone');
  const deviceId = clampText(identity.deviceId, 64, current.deviceId || 'default');
  return { deviceName, deviceId };
}

export function slugify(value, fallback = 'phone') {
  const normalized = String(value || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');
  return normalized || fallback;
}

export function compactId(value, fallback = 'default') {
  const normalized = String(value || '')
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '')
    .slice(-12);
  return normalized || fallback;
}

export function buildDeviceNames(phoneName, targets = {}) {
  const normalizedName = clampText(phoneName, 48, 'Phone');
  const cameraBase = `${normalizedName} Camera`;
  const micBase = `${normalizedName} Microphone`;
  const speakerBase = `${normalizedName} Speaker`;
  return {
    camera: targets.cameraTarget ? `${cameraBase} / ${targets.cameraTarget}` : cameraBase,
    microphone: targets.microphoneTarget ? `${micBase} / ${targets.microphoneTarget}` : micBase,
    speaker: targets.speakerTarget ? `${speakerBase} / ${targets.speakerTarget}` : speakerBase,
  };
}
