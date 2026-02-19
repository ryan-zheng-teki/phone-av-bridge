const state = {
  recorder: null,
  chunks: [],
  pollingTimer: null,
};

const els = {
  codexCommand: document.getElementById("codex-command"),
  codexCwd: document.getElementById("codex-cwd"),
  startCodex: document.getElementById("start-codex"),
  stopCodex: document.getElementById("stop-codex"),
  codexState: document.getElementById("codex-state"),
  modelSelect: document.getElementById("model-select"),
  language: document.getElementById("language"),
  recordButton: document.getElementById("record-button"),
  autoSend: document.getElementById("auto-send"),
  transcript: document.getElementById("transcript"),
  sendText: document.getElementById("send-text"),
  clearText: document.getElementById("clear-text"),
  sttStatus: document.getElementById("stt-status"),
  codexOutput: document.getElementById("codex-output"),
};

async function requestJson(url, options = {}) {
  const response = await fetch(url, options);
  const payload = await response.json();
  if (!response.ok) {
    throw new Error(payload.detail || "Request failed");
  }
  return payload;
}

async function loadModels() {
  const payload = await requestJson("/api/models");
  els.modelSelect.innerHTML = "";
  payload.choices.forEach((model) => {
    const option = document.createElement("option");
    option.value = model;
    option.textContent = model;
    if (model === payload.current) option.selected = true;
    els.modelSelect.appendChild(option);
  });
}

async function refreshOutput() {
  try {
    const payload = await requestJson("/api/codex/output?max_chars=12000");
    els.codexState.textContent = payload.running ? "running" : "stopped";
    els.codexOutput.textContent = payload.output || "";
    els.codexOutput.scrollTop = els.codexOutput.scrollHeight;
  } catch (error) {
    els.codexState.textContent = `error: ${error.message}`;
  }
}

async function startCodex() {
  const payload = {
    command: els.codexCommand.value.trim() || "codex",
    cwd: els.codexCwd.value.trim() || null,
  };
  await requestJson("/api/codex/start", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  await refreshOutput();
}

async function stopCodex() {
  await requestJson("/api/codex/stop", { method: "POST" });
  await refreshOutput();
}

async function sendTextToCodex() {
  const text = els.transcript.value.trim();
  if (!text) return;
  await requestJson("/api/codex/send", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ text }),
  });
  await refreshOutput();
}

async function onModelChange() {
  const model = els.modelSelect.value;
  await requestJson("/api/model/select", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ model }),
  });
  els.sttStatus.textContent = `model selected: ${model}`;
}

async function beginRecording() {
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    const preferredType = MediaRecorder.isTypeSupported("audio/webm;codecs=opus")
      ? "audio/webm;codecs=opus"
      : undefined;
    const recorder = preferredType ? new MediaRecorder(stream, { mimeType: preferredType }) : new MediaRecorder(stream);
    state.chunks = [];
    recorder.ondataavailable = (event) => {
      if (event.data && event.data.size > 0) state.chunks.push(event.data);
    };
    recorder.onstop = async () => {
      const blobType = preferredType || "audio/webm";
      const blob = new Blob(state.chunks, { type: blobType });
      stream.getTracks().forEach((track) => track.stop());
      if (!blob.size) {
        els.sttStatus.textContent = "No audio captured";
        return;
      }
      await transcribeBlob(blob);
    };
    recorder.start();
    state.recorder = recorder;
    els.recordButton.classList.add("active");
    els.sttStatus.textContent = "recording... release to transcribe";
  } catch (error) {
    els.sttStatus.textContent = `mic error: ${error.message}`;
  }
}

async function endRecording() {
  if (!state.recorder) return;
  state.recorder.stop();
  state.recorder = null;
  els.recordButton.classList.remove("active");
  els.sttStatus.textContent = "transcribing...";
}

async function transcribeBlob(blob) {
  const form = new FormData();
  form.append("file", blob, "speech.webm");
  form.append("language", els.language.value.trim() || "en");
  const payload = await requestJson("/api/transcribe", {
    method: "POST",
    body: form,
  });
  els.transcript.value = payload.text || "";
  els.sttStatus.textContent = `transcribed with ${payload.model}`;
  if (els.autoSend.checked && payload.text && payload.text.trim()) {
    await sendTextToCodex();
  }
}

function bindEvents() {
  els.startCodex.addEventListener("click", () => startCodex().catch(showError));
  els.stopCodex.addEventListener("click", () => stopCodex().catch(showError));
  els.sendText.addEventListener("click", () => sendTextToCodex().catch(showError));
  els.clearText.addEventListener("click", () => {
    els.transcript.value = "";
  });
  els.modelSelect.addEventListener("change", () => onModelChange().catch(showError));

  els.recordButton.addEventListener("mousedown", () => beginRecording().catch(showError));
  els.recordButton.addEventListener("mouseup", () => endRecording().catch(showError));
  els.recordButton.addEventListener("mouseleave", () => endRecording().catch(showError));
  els.recordButton.addEventListener("touchstart", (event) => {
    event.preventDefault();
    beginRecording().catch(showError);
  });
  els.recordButton.addEventListener("touchend", (event) => {
    event.preventDefault();
    endRecording().catch(showError);
  });
}

function showError(error) {
  els.sttStatus.textContent = `error: ${error.message}`;
}

async function init() {
  bindEvents();
  await loadModels();
  await refreshOutput();
  state.pollingTimer = setInterval(() => {
    refreshOutput().catch(() => {});
  }, 1200);
}

init().catch(showError);
