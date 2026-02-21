#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
VENV_DIR="${SCRIPT_DIR}/.venv"
VENV_PYTHON="${VENV_DIR}/bin/python3"

if ! command -v python3 >/dev/null 2>&1; then
  echo "[install] python3 not found in PATH." >&2
  exit 1
fi

if [[ ! -d "${VENV_DIR}" ]]; then
  echo "[install] creating virtualenv at ${VENV_DIR}"
  python3 -m venv "${VENV_DIR}"
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

echo "[install] done. Start with: ${SCRIPT_DIR}/voice-codex"
