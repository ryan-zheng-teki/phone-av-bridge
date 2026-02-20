async function api(path, method = 'GET', body) {
  const response = await fetch(path, {
    method,
    headers: body ? { 'Content-Type': 'application/json' } : undefined,
    body: body ? JSON.stringify(body) : undefined,
  });
  const payload = await response.json();
  if (!response.ok) {
    throw new Error(payload.error || `Request failed: ${path}`);
  }
  return payload;
}

let refreshPromise = null;
let latestQrPayloadText = '';
let latestQrExpiresAt = null;
let qrCountdownInterval = null;
let qrAutoRefreshTimeout = null;

function clearQrTimers() {
  if (qrCountdownInterval) {
    clearInterval(qrCountdownInterval);
    qrCountdownInterval = null;
  }
  if (qrAutoRefreshTimeout) {
    clearTimeout(qrAutoRefreshTimeout);
    qrAutoRefreshTimeout = null;
  }
}

function updateQrMeta() {
  const meta = document.getElementById('qrMetaText');
  if (!latestQrExpiresAt) {
    meta.textContent = 'QR code is not generated yet.';
    return;
  }
  const remainingMs = latestQrExpiresAt - Date.now();
  if (remainingMs <= 0) {
    meta.textContent = 'QR expired. Regenerating…';
    return;
  }
  const remainingSeconds = Math.ceil(remainingMs / 1000);
  meta.textContent = `QR active. Expires in ${remainingSeconds}s.`;
}

function scheduleQrRefresh() {
  if (!latestQrExpiresAt) {
    return;
  }
  const refreshAtMs = Math.max(1000, latestQrExpiresAt - Date.now() - 5000);
  qrAutoRefreshTimeout = setTimeout(() => {
    generateQrToken({ auto: true }).catch((error) => {
      document.getElementById('qrMetaText').textContent = `Auto-refresh failed: ${error.message}`;
    });
  }, refreshAtMs);
}

function renderQrToken(qrToken) {
  const qrPayload = qrToken.payload || {};
  const qrPayloadText = qrToken.payloadText || JSON.stringify(qrPayload);
  latestQrPayloadText = qrPayloadText;

  const expiresAt = Date.parse(qrToken.expiresAt || '');
  latestQrExpiresAt = Number.isFinite(expiresAt) ? expiresAt : null;
  clearQrTimers();
  updateQrMeta();
  qrCountdownInterval = setInterval(updateQrMeta, 1000);
  scheduleQrRefresh();

  const info = [
    `expiresAt: ${qrToken.expiresAt || 'unknown'}`,
    `token: ${qrToken.token || 'unknown'}`,
    `payload: ${qrPayloadText}`,
  ].join('\n');
  document.getElementById('qrTokenOut').textContent = info;

  const qrImage = document.getElementById('qrImage');
  qrImage.src = qrToken.qrImageDataUrl || `https://quickchart.io/qr?size=360&text=${encodeURIComponent(qrPayloadText)}`;
  qrImage.style.display = 'block';
  document.getElementById('copyQrPayloadBtn').disabled = false;
}

async function generateQrToken({ auto = false } = {}) {
  const payload = await api('/api/bootstrap/qr-token', 'POST');
  const qrToken = payload.qrToken || {};
  renderQrToken(qrToken);
  if (!auto) {
    document.getElementById('qrMetaText').textContent = 'QR regenerated successfully.';
    setTimeout(updateQrMeta, 1200);
  }
}

async function loadBootstrap() {
  const payload = await api('/api/bootstrap');
  const codeInput = document.getElementById('pairCode');
  codeInput.value = payload.bootstrap.pairingCode;
  codeInput.dataset.bootstrapCode = payload.bootstrap.pairingCode;
}

function renderStatus(status) {
  const statusText = document.getElementById('statusText');
  statusText.textContent = `${status.hostStatus} | paired=${status.paired} | camera=${status.resources.camera} mic=${status.resources.microphone} speaker=${status.resources.speaker}`;

  const phone = status.phone || {};
  const phoneText = document.getElementById('phoneText');
  const phoneName = phone.deviceName || 'unknown';
  const phoneId = phone.deviceId || 'unknown';
  phoneText.textContent = `Phone: ${phoneName} (${phoneId})`;

  const capabilities = status.capabilities || { camera: true, microphone: true, speaker: true };
  const capabilitySummary = document.getElementById('capabilitiesText');
  capabilitySummary.textContent = `Capabilities: camera=${capabilities.camera} mic=${capabilities.microphone} speaker=${capabilities.speaker}`;
  const routeHints = status.routeHints || {};
  const routeHintsText = document.getElementById('routeHintsText');
  routeHintsText.textContent = `Route hints:\n- Camera target: ${routeHints.camera || 'n/a'}\n- Microphone target: ${routeHints.microphone || 'n/a'}\n- Speaker target: ${routeHints.speaker || 'n/a'}`;
  const issuesText = document.getElementById('issuesText');
  const issues = Array.isArray(status.issues) ? status.issues : [];
  issuesText.textContent = issues.length === 0
    ? 'Issues: none'
    : `Issues:\n${issues.map((issue) => `- ${issue.resource}: ${issue.message}`).join('\n')}`;
  updateResourceChip('cameraStatusChip', evaluateResourceStatus({
    available: capabilities.camera,
    active: !!status.resources.camera,
    hasIssue: issues.some((issue) => issue.resource === 'camera'),
  }));
  updateResourceChip('micStatusChip', evaluateResourceStatus({
    available: capabilities.microphone,
    active: !!status.resources.microphone,
    hasIssue: issues.some((issue) => issue.resource === 'microphone'),
  }));
  updateResourceChip('speakerStatusChip', evaluateResourceStatus({
    available: capabilities.speaker,
    active: !!status.resources.speaker,
    hasIssue: issues.some((issue) => issue.resource === 'speaker'),
  }));
}

function evaluateResourceStatus({ available, active, hasIssue }) {
  if (!available) {
    return { label: 'Unavailable', className: 'chip-unavailable' };
  }
  if (hasIssue) {
    return { label: 'Issue', className: 'chip-issue' };
  }
  if (active) {
    return { label: 'Active', className: 'chip-active' };
  }
  return { label: 'Off', className: 'chip-off' };
}

function updateResourceChip(chipId, state) {
  const chip = document.getElementById(chipId);
  chip.textContent = state.label;
  chip.className = `status-chip ${state.className}`;
}

async function refresh() {
  if (refreshPromise) {
    return refreshPromise;
  }
  refreshPromise = (async () => {
  const payload = await api('/api/status');
  renderStatus(payload.status);
  if (payload.preflight) {
    document.getElementById('preflightOut').textContent = JSON.stringify(payload.preflight, null, 2);
  }
  })();
  try {
    await refreshPromise;
  } finally {
    refreshPromise = null;
  }
}

async function setup() {
  await loadBootstrap();
  document.getElementById('copyQrPayloadBtn').disabled = true;

  document.getElementById('pairBtn').addEventListener('click', async () => {
    const pairCode = document.getElementById('pairCode').value.trim();
    await api('/api/pair', 'POST', { pairCode });
    await refresh();
  });

  document.getElementById('unpairBtn').addEventListener('click', async () => {
    await api('/api/unpair', 'POST');
    await refresh();
  });

  document.getElementById('preflightBtn').addEventListener('click', async () => {
    const payload = await api('/api/preflight', 'POST');
    document.getElementById('preflightOut').textContent = JSON.stringify(payload.preflight, null, 2);
  });

  document.getElementById('qrTokenBtn').addEventListener('click', async () => {
    await generateQrToken();
  });

  document.getElementById('copyQrPayloadBtn').addEventListener('click', async () => {
    if (!latestQrPayloadText) {
      return;
    }
    try {
      await navigator.clipboard.writeText(latestQrPayloadText);
      document.getElementById('qrMetaText').textContent = 'QR payload copied to clipboard.';
      setTimeout(updateQrMeta, 1200);
    } catch (error) {
      document.getElementById('qrMetaText').textContent = `Clipboard copy failed: ${error.message}`;
    }
  });

  await generateQrToken({ auto: true });

  await refresh();

  setInterval(() => {
    refresh().catch((error) => {
      document.getElementById('statusText').textContent = `Status refresh error: ${error.message}`;
    });
  }, 2000);

  document.addEventListener('visibilitychange', () => {
    if (document.hidden) return;
    refresh().catch((error) => {
      document.getElementById('statusText').textContent = `Status refresh error: ${error.message}`;
    });
  });
}

setup().catch((error) => {
  document.getElementById('statusText').textContent = `Error: ${error.message}`;
});
