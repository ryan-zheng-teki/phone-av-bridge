#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
VENV_DIR="${SCRIPT_DIR}/.venv"
VENV_PYTHON="${VENV_DIR}/bin/python3"
LOCAL_BIN_DIR="${HOME}/.local/bin"
VOICE_CODEX_LINK="${LOCAL_BIN_DIR}/voice-codex"
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
ENV_FILE="${SCRIPT_DIR}/.voice-codex.env"

if ! command -v python3 >/dev/null 2>&1; then
  echo "[install] python3 not found in PATH." >&2
  exit 1
fi

if [[ ! -d "${VENV_DIR}" ]]; then
  echo "[install] creating virtualenv at ${VENV_DIR}"
  python3 -m venv "${VENV_DIR}"
fi

if [[ ! -f "${ENV_FILE}" ]]; then
  cat >"${ENV_FILE}" <<'EOF'
# Voice Codex defaults (loaded by ./voice-codex)
STT_MODEL=small
STT_LANGUAGE=zh

# Compatibility alias: if your external config writes LANG_CODE, keep it in sync.
# LANG_CODE=zh
EOF
  echo "[install] wrote default runtime config: ${ENV_FILE}"
fi

echo "[install] upgrading pip"
"${VENV_PYTHON}" -m pip install -U pip

echo "[install] installing Python dependencies"
"${VENV_PYTHON}" -m pip install -r "${SCRIPT_DIR}/requirements.txt"

echo "[install] validating Python imports"
"${VENV_PYTHON}" - <<'PY'
import importlib.util
missing = [m for m in ("faster_whisper", "requests") if importlib.util.find_spec(m) is None]
if missing:
    raise SystemExit(f"missing modules after install: {', '.join(missing)}")
print("[install] python dependency check passed")
PY

if ! command -v pactl >/dev/null 2>&1 || ! command -v parec >/dev/null 2>&1; then
  echo "[install] warning: pactl/parec not found. Install pulseaudio-utils before recording." >&2
fi

mkdir -p "${LOCAL_BIN_DIR}"
ln -sf "${SCRIPT_DIR}/voice-codex" "${VOICE_CODEX_LINK}"
echo "[install] linked ${VOICE_CODEX_LINK} -> ${SCRIPT_DIR}/voice-codex"

if ! grep -Fq "${PATH_LINE}" "${HOME}/.bashrc" 2>/dev/null; then
  echo "${PATH_LINE}" >> "${HOME}/.bashrc"
  echo "[install] added ~/.local/bin PATH export to ~/.bashrc"
fi

if [[ ":${PATH:-}:" != *":${LOCAL_BIN_DIR}:"* ]]; then
  export PATH="${LOCAL_BIN_DIR}:${PATH:-}"
  echo "[install] added ~/.local/bin to current shell PATH"
fi

echo "[install] done. Start with: voice-codex"
echo "[install] defaults: STT_MODEL=small, STT_LANGUAGE=zh (LANG_CODE supported via .voice-codex.env)"
