#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
VENV_DIR="${SCRIPT_DIR}/.venv"
VENV_PYTHON="${VENV_DIR}/bin/python3"
LOCAL_BIN_DIR="${HOME}/.local/bin"
VOICE_GEMINI_LINK="${LOCAL_BIN_DIR}/voice-gemini"
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
ENV_FILE="${SCRIPT_DIR}/.voice-gemini.env"
MIN_PY_MINOR=9
MAX_PY_MINOR=13

is_supported_python() {
  local cmd="$1"
  "${cmd}" - <<PY >/dev/null 2>&1
import sys
ok = (sys.version_info.major == 3 and ${MIN_PY_MINOR} <= sys.version_info.minor <= ${MAX_PY_MINOR})
raise SystemExit(0 if ok else 1)
PY
}

select_python_cmd() {
  local candidates=()
  if [[ -n "${VOICE_GEMINI_PYTHON:-}" ]]; then
    candidates+=("${VOICE_GEMINI_PYTHON}")
  fi
  candidates+=(python3.11 python3.12 python3.13 python3.10 python3.9 python3)

  local candidate
  for candidate in "${candidates[@]}"; do
    if ! command -v "${candidate}" >/dev/null 2>&1; then
      continue
    fi
    if is_supported_python "${candidate}"; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done
  return 1
}

if [[ -x "${VENV_PYTHON}" ]] && ! is_supported_python "${VENV_PYTHON}"; then
  echo "[install] existing .venv python is unsupported; recreating with Python 3.${MIN_PY_MINOR}-3.${MAX_PY_MINOR}." >&2
  rm -rf "${VENV_DIR}"
fi

if [[ ! -x "${VENV_PYTHON}" ]]; then
  if ! PYTHON_CMD="$(select_python_cmd)"; then
    echo "[install] no supported Python found. Install Python 3.${MIN_PY_MINOR}-3.${MAX_PY_MINOR} or set VOICE_GEMINI_PYTHON." >&2
    exit 1
  fi
  echo "[install] creating virtualenv at ${VENV_DIR} using ${PYTHON_CMD}"
  "${PYTHON_CMD}" -m venv "${VENV_DIR}"
fi

if [[ ! -f "${ENV_FILE}" ]]; then
  cat >"${ENV_FILE}" <<'ENVEOF'
# Voice Gemini defaults (loaded by ./voice-gemini)
STT_MODEL=tiny.en
STT_LANGUAGE=en

# Compatibility alias: if your external config writes LANG_CODE, keep it in sync.
# LANG_CODE=en

# Audio Configuration
VOICE_GEMINI_RECORD_SOURCE=
VOICE_GEMINI_SAMPLE_RATE=16000

# Hotkey Configuration (ctrl-g, ctrl-r, ctrl-x, f8, f9, enter)
VOICE_GEMINI_RECORD_KEY=ctrl-g

# Command Configuration
GEMINI_CMD=gemini
ENVEOF
  echo "[install] wrote default runtime config: ${ENV_FILE}"
fi

echo "[install] upgrading pip"
"${VENV_PYTHON}" -m pip install -q -U pip

echo "[install] installing Python dependencies"
"${VENV_PYTHON}" -m pip install -q -r "${SCRIPT_DIR}/requirements.txt"

echo "[install] validating Python imports"
"${VENV_PYTHON}" - <<'PY'
import importlib.util
missing = [m for m in ("faster_whisper", "requests") if importlib.util.find_spec(m) is None]
if missing:
    raise SystemExit(f"missing modules after install: {', '.join(missing)}")
print("[install] python dependency check passed")
PY

case "$(uname -s)" in
  Linux*)
    if ! command -v pactl >/dev/null 2>&1 || ! command -v parec >/dev/null 2>&1; then
      echo "[install] warning: pactl/parec not found. Install pulseaudio-utils before recording." >&2
    fi
    ;;
  Darwin*)
    if ! command -v ffmpeg >/dev/null 2>&1; then
      echo "[install] warning: ffmpeg not found. Install with: brew install ffmpeg" >&2
    fi
    ;;
  *)
    echo "[install] warning: unsupported platform for voice recording backend." >&2
    ;;
esac

mkdir -p "${LOCAL_BIN_DIR}"
ln -sf "${SCRIPT_DIR}/voice-gemini" "${VOICE_GEMINI_LINK}"
echo "[install] linked ${VOICE_GEMINI_LINK} -> ${SCRIPT_DIR}/voice-gemini"

ensure_path_line() {
  local rc_file="$1"
  if [[ -f "${rc_file}" ]] && ! grep -Fq "${PATH_LINE}" "${rc_file}" 2>/dev/null; then
    echo "${PATH_LINE}" >> "${rc_file}"
    echo "[install] added ~/.local/bin PATH export to ${rc_file}"
  fi
}

ensure_path_line "${HOME}/.bashrc"
ensure_path_line "${HOME}/.zshrc"

if [[ ":${PATH:-}:" != *":${LOCAL_BIN_DIR}:"* ]]; then
  export PATH="${LOCAL_BIN_DIR}:${PATH:-}"
  echo "[install] added ~/.local/bin to current shell PATH"
fi

echo "[install] done. Start with: voice-gemini"
