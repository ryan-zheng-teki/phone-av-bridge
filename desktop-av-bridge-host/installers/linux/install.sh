#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TARGET_DIR="${HOME}/.local/share/phone-av-bridge-host"
BIN_DIR="${HOME}/.local/bin"
APP_DIR="${HOME}/.local/share/applications"
LOG_DIR="${HOME}/.local/state/phone-av-bridge-host"
USER_CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/phone-av-bridge-host"
USER_ENV_FILE="${USER_CONFIG_DIR}/env"
RUNTIME_NODE="${TARGET_DIR}/runtime/node/bin/node"
SYSTEM_NODE="$(command -v node || true)"
AUTO_INSTALL_DEPS="${AUTO_INSTALL_DEPS:-1}"
INSTALL_COMPAT_CAMERA="${INSTALL_COMPAT_CAMERA:-1}"
V4L2_VIDEO_NR="${V4L2_VIDEO_NR:-2}"
V4L2_CARD_LABEL="${V4L2_CARD_LABEL:-AutoByteusPhoneCamera}"

if [[ "${INSTALL_COMPAT_CAMERA}" == "1" ]]; then
  LINUX_CAMERA_MODE_DEFAULT="${LINUX_CAMERA_MODE_DEFAULT:-compatibility}"
else
  LINUX_CAMERA_MODE_DEFAULT="${LINUX_CAMERA_MODE_DEFAULT:-userspace}"
fi
V4L2_DEVICE_DEFAULT="${V4L2_DEVICE_DEFAULT:-/dev/video${V4L2_VIDEO_NR}}"

mkdir -p "${TARGET_DIR}" "${BIN_DIR}" "${APP_DIR}" "${LOG_DIR}" "${USER_CONFIG_DIR}"

if [[ ! -f "${USER_ENV_FILE}" ]]; then
  cat > "${USER_ENV_FILE}" <<EOF
# Phone AV Bridge host defaults (optional overrides)
LINUX_CAMERA_MODE=${LINUX_CAMERA_MODE_DEFAULT}
V4L2_DEVICE=${V4L2_DEVICE_DEFAULT}
# Optional: set speaker capture source explicitly instead of automatic safe selection.
# LINUX_SPEAKER_CAPTURE_SOURCE=alsa_output.pci-0000_00_1f.3.analog-stereo.monitor
EOF
fi

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

  # Reload to ensure updated module parameters are actually applied.
  sudo modprobe -r v4l2loopback || true
  sudo modprobe v4l2loopback "video_nr=${V4L2_VIDEO_NR}" card_label="${V4L2_CARD_LABEL}" exclusive_caps=0 max_buffers=2 || true
  if [[ -d /etc/modprobe.d ]]; then
    printf 'options v4l2loopback video_nr=%s card_label=%s exclusive_caps=0 max_buffers=2\n' "${V4L2_VIDEO_NR}" "${V4L2_CARD_LABEL}" \
      | sudo tee /etc/modprobe.d/phone-av-bridge-v4l2loopback.conf >/dev/null || true
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

BRIDGE_RUNTIME_SOURCE="$(cd "${PROJECT_ROOT}/.." && pwd)/phone-av-camera-bridge-runtime"
if [[ -d "${BRIDGE_RUNTIME_SOURCE}" ]]; then
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "${BRIDGE_RUNTIME_SOURCE}/" "${TARGET_DIR}/phone-av-camera-bridge-runtime/"
  else
    rm -rf "${TARGET_DIR}/phone-av-camera-bridge-runtime"
    mkdir -p "${TARGET_DIR}/phone-av-camera-bridge-runtime"
    cp -a "${BRIDGE_RUNTIME_SOURCE}/." "${TARGET_DIR}/phone-av-camera-bridge-runtime/"
  fi
else
  echo "Warning: ${BRIDGE_RUNTIME_SOURCE} not found. Linux camera bridge runtime was not bundled." >&2
fi

if [[ "${runtime_usable}" -ne 1 && -z "${SYSTEM_NODE}" ]]; then
  echo "Neither bundled runtime nor system Node.js was found." >&2
  echo "Install Node 20+ and run installer again." >&2
  exit 1
fi

cat > "${BIN_DIR}/phone-av-bridge-host-start" <<'LAUNCHER'
#!/usr/bin/env bash
set -euo pipefail
TARGET_DIR="${HOME}/.local/share/phone-av-bridge-host"
LOG_DIR="${HOME}/.local/state/phone-av-bridge-host"
PID_FILE="${LOG_DIR}/phone-av-bridge-host.pid"
RUNTIME_NODE="${TARGET_DIR}/runtime/node/bin/node"
LINUX_CAMERA_MODE_DEFAULT="{{LINUX_CAMERA_MODE_DEFAULT}}"
V4L2_DEVICE_DEFAULT="{{V4L2_DEVICE_DEFAULT}}"
USER_ENV_FILE="${XDG_CONFIG_HOME:-${HOME}/.config}/phone-av-bridge-host/env"

mkdir -p "${LOG_DIR}"

if [[ -f "${USER_ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  . "${USER_ENV_FILE}"
  set +a
fi

kill_tree() {
  local pid="$1"
  local child
  for child in $(pgrep -P "${pid}" 2>/dev/null || true); do
    kill_tree "${child}"
  done
  kill "${pid}" >/dev/null 2>&1 || true
}

cleanup_stale_media_workers() {
  local bridge_pid
  for bridge_pid in $(pgrep -f "${TARGET_DIR}/phone-av-camera-bridge-runtime/bin/run-bridge.sh" 2>/dev/null || true); do
    kill_tree "${bridge_pid}"
  done

  local mic_pid
  for mic_pid in $(pgrep -f 'ffmpeg .* -f pulse phone_av_bridge_mic_sink_' 2>/dev/null || true); do
    kill "${mic_pid}" >/dev/null 2>&1 || true
  done

  if command -v pactl >/dev/null 2>&1; then
    pactl list short modules 2>/dev/null | awk -F'\t' '/phone_av_bridge_mic_sink_|phone_av_bridge_mic_input_/ {print $1}' | while read -r module_id; do
      if [[ -n "${module_id}" ]]; then
        pactl unload-module "${module_id}" >/dev/null 2>&1 || true
      fi
    done
  fi
}

if [[ -x "${RUNTIME_NODE}" ]] && "${RUNTIME_NODE}" --version >/dev/null 2>&1; then
  NODE_BIN="${RUNTIME_NODE}"
elif command -v node >/dev/null 2>&1; then
  NODE_BIN="$(command -v node)"
else
  echo "Phone AV Bridge Host cannot start because Node.js runtime is unavailable." >&2
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

cleanup_stale_media_workers

cd "${TARGET_DIR}"
"${NODE_BIN}" desktop-app/server.mjs >"${LOG_DIR}/phone-av-bridge-host.log" 2>&1 &
echo $! > "${PID_FILE}"
sleep 1
if ! kill -0 "$(cat "${PID_FILE}")" >/dev/null 2>&1; then
  echo "Phone AV Bridge Host failed to start. Check ${LOG_DIR}/phone-av-bridge-host.log" >&2
  exit 1
fi
if command -v xdg-open >/dev/null 2>&1; then
  xdg-open "http://127.0.0.1:8787" >/dev/null 2>&1 || true
fi
LAUNCHER
sed -i.bak "s|{{LINUX_CAMERA_MODE_DEFAULT}}|${LINUX_CAMERA_MODE_DEFAULT}|g; s|{{V4L2_DEVICE_DEFAULT}}|${V4L2_DEVICE_DEFAULT}|g" "${BIN_DIR}/phone-av-bridge-host-start"
rm -f "${BIN_DIR}/phone-av-bridge-host-start.bak"
chmod +x "${BIN_DIR}/phone-av-bridge-host-start"

cat > "${BIN_DIR}/phone-av-bridge-host-stop" <<'STOPPER'
#!/usr/bin/env bash
set -euo pipefail
PID_FILE="${HOME}/.local/state/phone-av-bridge-host/phone-av-bridge-host.pid"
TARGET_DIR="${HOME}/.local/share/phone-av-bridge-host"

kill_tree() {
  local pid="$1"
  local child
  for child in $(pgrep -P "${pid}" 2>/dev/null || true); do
    kill_tree "${child}"
  done
  kill "${pid}" >/dev/null 2>&1 || true
}

cleanup_stale_media_workers() {
  local bridge_pid
  for bridge_pid in $(pgrep -f "${TARGET_DIR}/phone-av-camera-bridge-runtime/bin/run-bridge.sh" 2>/dev/null || true); do
    kill_tree "${bridge_pid}"
  done
  local mic_pid
  for mic_pid in $(pgrep -f 'ffmpeg .* -f pulse phone_av_bridge_mic_sink_' 2>/dev/null || true); do
    kill "${mic_pid}" >/dev/null 2>&1 || true
  done
}

if [[ ! -f "${PID_FILE}" ]]; then
  cleanup_stale_media_workers
  exit 0
fi

PID="$(cat "${PID_FILE}")"
if kill -0 "${PID}" >/dev/null 2>&1; then
  kill_tree "${PID}"
fi
cleanup_stale_media_workers
rm -f "${PID_FILE}"
STOPPER
chmod +x "${BIN_DIR}/phone-av-bridge-host-stop"

cat > "${APP_DIR}/phone-av-bridge-host.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Phone AV Bridge Host
Exec=${BIN_DIR}/phone-av-bridge-host-start
Terminal=false
Categories=AudioVideo;Network;
DESKTOP

echo "Installed Phone AV Bridge Host."
echo "Launch from app menu: Phone AV Bridge Host"
echo "Start command: ${BIN_DIR}/phone-av-bridge-host-start"
echo "Stop command: ${BIN_DIR}/phone-av-bridge-host-stop"
echo "Uninstall script: ${TARGET_DIR}/installers/linux/uninstall.sh"
echo "Camera mode default: ${LINUX_CAMERA_MODE_DEFAULT} (override with env LINUX_CAMERA_MODE)"
echo "Camera compatibility label: ${V4L2_CARD_LABEL} (override with env V4L2_CARD_LABEL)"
echo "Persistent user config: ${USER_ENV_FILE}"
runtime_usable=0
if [[ -x "${RUNTIME_NODE}" ]] && "${RUNTIME_NODE}" --version >/dev/null 2>&1; then
  runtime_usable=1
fi
