#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${PROJECT_ROOT}/.." && pwd)"
DIST_DIR="${PROJECT_ROOT}/dist"
PACKAGE_NAME="phone-av-bridge-host"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require_cmd node
require_cmd dpkg-deb
require_cmd dpkg

VERSION_INPUT="${1:-${VERSION:-}}"
if [[ -z "${VERSION_INPUT}" ]]; then
  VERSION_INPUT="$(node -p "require('${PROJECT_ROOT}/package.json').version")"
fi

VERSION="${VERSION_INPUT#v}"
VERSION="${VERSION//[^0-9A-Za-z.+:~-]/-}"
if [[ -z "${VERSION}" ]]; then
  echo "Package version is empty after normalization." >&2
  exit 1
fi

ARCH="${DEB_ARCH:-$(dpkg --print-architecture)}"

WORK_DIR="$(mktemp -d)"
PKG_ROOT="${WORK_DIR}/pkg"
PAYLOAD_ROOT="${PKG_ROOT}/opt/phone-av-bridge-host"
DEBIAN_DIR="${PKG_ROOT}/DEBIAN"
USR_BIN_DIR="${PKG_ROOT}/usr/bin"
DESKTOP_DIR="${PKG_ROOT}/usr/share/applications"
BRIDGE_RUNTIME_SOURCE="${REPO_ROOT}/phone-av-camera-bridge-runtime"

cleanup() {
  rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

mkdir -p "${DIST_DIR}" "${PAYLOAD_ROOT}" "${DEBIAN_DIR}" "${USR_BIN_DIR}" "${DESKTOP_DIR}"

echo "Preparing bundled Node runtime..."
node "${PROJECT_ROOT}/scripts/prepare-runtime.mjs"

echo "Staging package payload..."
for item in package.json README.md core adapters desktop-app installers scripts runtime; do
  cp -a "${PROJECT_ROOT}/${item}" "${PAYLOAD_ROOT}/"
done

if [[ -d "${BRIDGE_RUNTIME_SOURCE}" ]]; then
  cp -a "${BRIDGE_RUNTIME_SOURCE}" "${PAYLOAD_ROOT}/phone-av-camera-bridge-runtime"
else
  echo "Missing bridge runtime directory: ${BRIDGE_RUNTIME_SOURCE}" >&2
  exit 1
fi

cat > "${USR_BIN_DIR}/phone-av-bridge-host-start" <<'LAUNCHER'
#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="/opt/phone-av-bridge-host"
LOG_ROOT="${XDG_STATE_HOME:-${HOME}/.local/state}"
LOG_DIR="${LOG_ROOT}/phone-av-bridge-host"
PID_FILE="${LOG_DIR}/phone-av-bridge-host.pid"
RUNTIME_NODE="${TARGET_DIR}/runtime/node/bin/node"

mkdir -p "${LOG_DIR}"

if [[ -x "${RUNTIME_NODE}" ]] && "${RUNTIME_NODE}" --version >/dev/null 2>&1; then
  NODE_BIN="${RUNTIME_NODE}"
elif command -v node >/dev/null 2>&1; then
  NODE_BIN="$(command -v node)"
else
  echo "Phone AV Bridge Host cannot start because Node.js runtime is unavailable." >&2
  exit 1
fi

export LINUX_CAMERA_MODE="${LINUX_CAMERA_MODE:-compatibility}"
export V4L2_DEVICE="${V4L2_DEVICE:-/dev/video2}"

if [[ -f "${PID_FILE}" ]] && kill -0 "$(cat "${PID_FILE}")" >/dev/null 2>&1; then
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "http://127.0.0.1:8787" >/dev/null 2>&1 || true
  fi
  exit 0
fi

cd "${TARGET_DIR}"
nohup "${NODE_BIN}" desktop-app/server.mjs >"${LOG_DIR}/phone-av-bridge-host.log" 2>&1 &
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

cat > "${USR_BIN_DIR}/phone-av-bridge-host-stop" <<'STOPPER'
#!/usr/bin/env bash
set -euo pipefail

LOG_ROOT="${XDG_STATE_HOME:-${HOME}/.local/state}"
PID_FILE="${LOG_ROOT}/phone-av-bridge-host/phone-av-bridge-host.pid"

if [[ ! -f "${PID_FILE}" ]]; then
  exit 0
fi

PID="$(cat "${PID_FILE}")"
if kill -0 "${PID}" >/dev/null 2>&1; then
  kill "${PID}" >/dev/null 2>&1 || true
fi
rm -f "${PID_FILE}"
STOPPER

cat > "${USR_BIN_DIR}/phone-av-bridge-host-enable-camera" <<'CAMERAFIX'
#!/usr/bin/env bash
set -euo pipefail

VIDEO_NR="${V4L2_VIDEO_NR:-2}"
CARD_LABEL="${V4L2_CARD_LABEL:-AutoByteusPhoneCamera}"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Run with sudo: sudo phone-av-bridge-host-enable-camera" >&2
  exit 1
fi

mkdir -p /etc/modprobe.d /etc/modules-load.d
printf 'options v4l2loopback video_nr=%s card_label=%s exclusive_caps=0 max_buffers=2\n' "${VIDEO_NR}" "${CARD_LABEL}" > /etc/modprobe.d/phone-av-bridge-v4l2loopback.conf
printf 'v4l2loopback\n' > /etc/modules-load.d/phone-av-bridge-v4l2loopback.conf
modprobe -r v4l2loopback || true
modprobe v4l2loopback video_nr="${VIDEO_NR}" card_label="${CARD_LABEL}" exclusive_caps=0 max_buffers=2
echo "v4l2loopback loaded at /dev/video${VIDEO_NR} with label ${CARD_LABEL}"
CAMERAFIX

chmod 0755 "${USR_BIN_DIR}/phone-av-bridge-host-start" "${USR_BIN_DIR}/phone-av-bridge-host-stop" "${USR_BIN_DIR}/phone-av-bridge-host-enable-camera"

cat > "${DESKTOP_DIR}/phone-av-bridge-host.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Phone AV Bridge Host
Exec=/usr/bin/phone-av-bridge-host-start
Terminal=false
Categories=AudioVideo;Network;
DESKTOP

INSTALLED_SIZE="$(du -sk "${PKG_ROOT}" | awk '{print $1}')"

cat > "${DEBIAN_DIR}/control" <<CONTROL
Package: ${PACKAGE_NAME}
Version: ${VERSION}
Section: video
Priority: optional
Architecture: ${ARCH}
Maintainer: Phone AV Bridge Maintainers <noreply@users.noreply.github.com>
Depends: ffmpeg, pulseaudio-utils
Recommends: v4l2loopback-dkms, v4l2loopback-utils
Installed-Size: ${INSTALLED_SIZE}
Description: Phone AV Bridge desktop host
 Linux and macOS host orchestrator for phone camera, microphone, and speaker bridging.
 Includes local web host UI/API and launchers.
CONTROL

cat > "${DEBIAN_DIR}/postinst" <<'POSTINST'
#!/usr/bin/env bash
set -euo pipefail

VIDEO_NR="${V4L2_VIDEO_NR:-2}"
CARD_LABEL="${V4L2_CARD_LABEL:-AutoByteusPhoneCamera}"
MODPROBE_CONF="/etc/modprobe.d/phone-av-bridge-v4l2loopback.conf"
MODULES_LOAD_CONF="/etc/modules-load.d/phone-av-bridge-v4l2loopback.conf"

mkdir -p /etc/modprobe.d /etc/modules-load.d
printf 'options v4l2loopback video_nr=%s card_label=%s exclusive_caps=0 max_buffers=2\n' "${VIDEO_NR}" "${CARD_LABEL}" > "${MODPROBE_CONF}" || true
printf 'v4l2loopback\n' > "${MODULES_LOAD_CONF}" || true

if command -v modprobe >/dev/null 2>&1; then
  modprobe -r v4l2loopback || true
  modprobe v4l2loopback video_nr="${VIDEO_NR}" card_label="${CARD_LABEL}" exclusive_caps=0 max_buffers=2 || true
fi
POSTINST

cat > "${DEBIAN_DIR}/postrm" <<'POSTRM'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "purge" ]]; then
  rm -f /etc/modules-load.d/phone-av-bridge-v4l2loopback.conf || true
  rm -f /etc/modprobe.d/phone-av-bridge-v4l2loopback.conf || true
fi
POSTRM

chmod 0755 "${DEBIAN_DIR}/postinst" "${DEBIAN_DIR}/postrm"

DEB_NAME="${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"
DEB_PATH="${DIST_DIR}/${DEB_NAME}"
rm -f "${DEB_PATH}"

echo "Building Debian package..."
dpkg-deb --build --root-owner-group "${PKG_ROOT}" "${DEB_PATH}" >/dev/null

echo "Debian package created: ${DEB_PATH}"
echo "artifact_path=${DEB_PATH}"
