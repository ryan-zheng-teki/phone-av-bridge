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

  document.getElementById('cameraToggle').checked = !!status.resources.camera;
  document.getElementById('micToggle').checked = !!status.resources.microphone;
  document.getElementById('speakerToggle').checked = !!status.resources.speaker;
  document.getElementById('cameraToggle').disabled = !capabilities.camera;
  document.getElementById('micToggle').disabled = !capabilities.microphone;
  document.getElementById('speakerToggle').disabled = !capabilities.speaker;
}

async function refresh() {
  const payload = await api('/api/status');
  renderStatus(payload.status);
  if (payload.preflight) {
    document.getElementById('preflightOut').textContent = JSON.stringify(payload.preflight, null, 2);
  }
}

async function setup() {
  await loadBootstrap();

  document.getElementById('pairBtn').addEventListener('click', async () => {
    const pairCode = document.getElementById('pairCode').value.trim();
    await api('/api/pair', 'POST', { pairCode });
    await refresh();
  });

  document.getElementById('unpairBtn').addEventListener('click', async () => {
    await api('/api/unpair', 'POST');
    await refresh();
  });

  document.getElementById('applyBtn').addEventListener('click', async () => {
    await api('/api/toggles', 'POST', {
      camera: document.getElementById('cameraToggle').checked,
      microphone: document.getElementById('micToggle').checked,
      speaker: document.getElementById('speakerToggle').checked,
    });
    await refresh();
  });

  document.getElementById('preflightBtn').addEventListener('click', async () => {
    const payload = await api('/api/preflight', 'POST');
    document.getElementById('preflightOut').textContent = JSON.stringify(payload.preflight, null, 2);
  });

  await refresh();
}

setup().catch((error) => {
  document.getElementById('statusText').textContent = `Error: ${error.message}`;
});
