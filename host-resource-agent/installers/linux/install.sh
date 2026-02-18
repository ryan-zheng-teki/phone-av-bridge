#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TARGET_DIR="${HOME}/.local/share/host-resource-agent"
BIN_DIR="${HOME}/.local/bin"
APP_DIR="${HOME}/.local/share/applications"
LOG_DIR="${HOME}/.local/state/host-resource-agent"
RUNTIME_NODE="${TARGET_DIR}/runtime/node/bin/node"
SYSTEM_NODE="$(command -v node || true)"
AUTO_INSTALL_DEPS="${AUTO_INSTALL_DEPS:-1}"
INSTALL_COMPAT_CAMERA="${INSTALL_COMPAT_CAMERA:-1}"
V4L2_VIDEO_NR="${V4L2_VIDEO_NR:-2}"

if [[ "${INSTALL_COMPAT_CAMERA}" == "1" ]]; then
  LINUX_CAMERA_MODE_DEFAULT="${LINUX_CAMERA_MODE_DEFAULT:-compatibility}"
else
  LINUX_CAMERA_MODE_DEFAULT="${LINUX_CAMERA_MODE_DEFAULT:-userspace}"
fi
V4L2_DEVICE_DEFAULT="${V4L2_DEVICE_DEFAULT:-/dev/video${V4L2_VIDEO_NR}}"

mkdir -p "${TARGET_DIR}" "${BIN_DIR}" "${APP_DIR}" "${LOG_DIR}"

runtime_usable=0
if [[ -x "${RUNTIME_NODE}" ]] && "${RUNTIME_NODE}" --version >/dev/null 2>&1; then
  runtime_usable=1
fi

ensure_linux_dependencies() {
  if [[ "${AUTO_INSTALL_DEPS}" != "1" ]]; then
    return 0
  fi

  if ! command -v sudo >/dev/null 2>&1; then
    return 0
  fi

  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -y || true
    sudo apt-get install -y ffmpeg pulseaudio-utils || true
    if [[ "${INSTALL_COMPAT_CAMERA}" == "1" ]]; then
      sudo apt-get install -y v4l2loopback-dkms v4l2loopback-utils || true
    fi
    return 0
  fi
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y ffmpeg pulseaudio-utils || true
    if [[ "${INSTALL_COMPAT_CAMERA}" == "1" ]]; then
      sudo dnf install -y akmod-v4l2loopback v4l-utils || true
    fi
    return 0
  fi
  if command -v pacman >/dev/null 2>&1; then
    sudo pacman -Sy --noconfirm ffmpeg pipewire-pulse || true
    if [[ "${INSTALL_COMPAT_CAMERA}" == "1" ]]; then
      sudo pacman -Sy --noconfirm v4l2loopback-dkms v4l-utils || true
    fi
    return 0
  fi
}

configure_v4l2_compatibility() {
  if [[ "${INSTALL_COMPAT_CAMERA}" != "1" ]]; then
    return 0
  fi
  if ! command -v sudo >/dev/null 2>&1; then
    return 0
  fi
  if ! command -v modprobe >/dev/null 2>&1; then
    return 0
  fi

  sudo modprobe v4l2loopback "video_nr=${V4L2_VIDEO_NR}" card_label="PhoneResourceCamera" exclusive_caps=1 || true
  if [[ -d /etc/modprobe.d ]]; then
    printf 'options v4l2loopback video_nr=%s card_label=PhoneResourceCamera exclusive_caps=1\n' "${V4L2_VIDEO_NR}" \
      | sudo tee /etc/modprobe.d/phone-resource-companion-v4l2loopback.conf >/dev/null || true
  fi
}

ensure_linux_dependencies
configure_v4l2_compatibility

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "Warning: ffmpeg not found. Camera routing will not work until ffmpeg is installed." >&2
fi
if ! command -v pactl >/dev/null 2>&1; then
  echo "Warning: pactl not found. Microphone virtual routing may not work until Pulse/PipeWire tooling is installed." >&2
fi
if [[ "${INSTALL_COMPAT_CAMERA}" == "1" ]] && [[ ! -e "${V4L2_DEVICE_DEFAULT}" ]]; then
  echo "Warning: ${V4L2_DEVICE_DEFAULT} is not present. Compatibility camera mode may require reboot or manual module load." >&2
fi

if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete "${PROJECT_ROOT}/" "${TARGET_DIR}/"
else
  rm -rf "${TARGET_DIR}"
  mkdir -p "${TARGET_DIR}"
  cp -a "${PROJECT_ROOT}/." "${TARGET_DIR}/"
fi

if [[ "${runtime_usable}" -ne 1 && -z "${SYSTEM_NODE}" ]]; then
  echo "Neither bundled runtime nor system Node.js was found." >&2
  echo "Install Node 20+ and run installer again." >&2
  exit 1
fi

cat > "${BIN_DIR}/host-resource-agent-start" <<'LAUNCHER'
#!/usr/bin/env bash
set -euo pipefail
TARGET_DIR="${HOME}/.local/share/host-resource-agent"
LOG_DIR="${HOME}/.local/state/host-resource-agent"
PID_FILE="${LOG_DIR}/host-resource-agent.pid"
RUNTIME_NODE="${TARGET_DIR}/runtime/node/bin/node"
LINUX_CAMERA_MODE_DEFAULT="{{LINUX_CAMERA_MODE_DEFAULT}}"
V4L2_DEVICE_DEFAULT="{{V4L2_DEVICE_DEFAULT}}"

mkdir -p "${LOG_DIR}"

if [[ -x "${RUNTIME_NODE}" ]] && "${RUNTIME_NODE}" --version >/dev/null 2>&1; then
  NODE_BIN="${RUNTIME_NODE}"
elif command -v node >/dev/null 2>&1; then
  NODE_BIN="$(command -v node)"
else
  echo "Host Resource Agent cannot start because Node.js runtime is unavailable." >&2
  exit 1
fi

export LINUX_CAMERA_MODE="${LINUX_CAMERA_MODE:-${LINUX_CAMERA_MODE_DEFAULT}}"
export V4L2_DEVICE="${V4L2_DEVICE:-${V4L2_DEVICE_DEFAULT}}"

if [[ -f "${PID_FILE}" ]] && kill -0 "$(cat "${PID_FILE}")" >/dev/null 2>&1; then
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "http://127.0.0.1:8787" >/dev/null 2>&1 || true
  fi
  exit 0
fi

cd "${TARGET_DIR}"
"${NODE_BIN}" linux-app/server.mjs >"${LOG_DIR}/host-resource-agent.log" 2>&1 &
echo $! > "${PID_FILE}"
sleep 1
if ! kill -0 "$(cat "${PID_FILE}")" >/dev/null 2>&1; then
  echo "Host Resource Agent failed to start. Check ${LOG_DIR}/host-resource-agent.log" >&2
  exit 1
fi
if command -v xdg-open >/dev/null 2>&1; then
  xdg-open "http://127.0.0.1:8787" >/dev/null 2>&1 || true
fi
LAUNCHER
sed -i.bak "s|{{LINUX_CAMERA_MODE_DEFAULT}}|${LINUX_CAMERA_MODE_DEFAULT}|g; s|{{V4L2_DEVICE_DEFAULT}}|${V4L2_DEVICE_DEFAULT}|g" "${BIN_DIR}/host-resource-agent-start"
rm -f "${BIN_DIR}/host-resource-agent-start.bak"
chmod +x "${BIN_DIR}/host-resource-agent-start"

cat > "${BIN_DIR}/host-resource-agent-stop" <<'STOPPER'
#!/usr/bin/env bash
set -euo pipefail
PID_FILE="${HOME}/.local/state/host-resource-agent/host-resource-agent.pid"

if [[ ! -f "${PID_FILE}" ]]; then
  exit 0
fi

PID="$(cat "${PID_FILE}")"
if kill -0 "${PID}" >/dev/null 2>&1; then
  kill "${PID}" >/dev/null 2>&1 || true
fi
rm -f "${PID_FILE}"
STOPPER
chmod +x "${BIN_DIR}/host-resource-agent-stop"

cat > "${APP_DIR}/host-resource-agent.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Host Resource Agent
Exec=${BIN_DIR}/host-resource-agent-start
Terminal=false
Categories=AudioVideo;Network;
DESKTOP

echo "Installed Host Resource Agent."
echo "Launch from app menu: Host Resource Agent"
echo "Start command: ${BIN_DIR}/host-resource-agent-start"
echo "Stop command: ${BIN_DIR}/host-resource-agent-stop"
echo "Uninstall script: ${TARGET_DIR}/installers/linux/uninstall.sh"
echo "Camera mode default: ${LINUX_CAMERA_MODE_DEFAULT} (override with env LINUX_CAMERA_MODE)"
runtime_usable=0
if [[ -x "${RUNTIME_NODE}" ]] && "${RUNTIME_NODE}" --version >/dev/null 2>&1; then
  runtime_usable=1
fi
