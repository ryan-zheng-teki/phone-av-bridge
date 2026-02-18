#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TARGET_DIR="${HOME}/Applications/HostResourceAgent"
APP_BUNDLE="${HOME}/Applications/Host Resource Agent.app"
LOG_DIR="${HOME}/Library/Logs/HostResourceAgent"
RUNTIME_NODE="${TARGET_DIR}/runtime/node/bin/node"
AUTO_INSTALL_DEPS="${AUTO_INSTALL_DEPS:-1}"

mkdir -p "${TARGET_DIR}" "${LOG_DIR}"

ensure_brew_package() {
  local formula="$1"
  if brew list "${formula}" >/dev/null 2>&1; then
    return 0
  fi
  echo "Installing ${formula} via Homebrew..."
  brew install "${formula}" || return 1
}

if [[ "${AUTO_INSTALL_DEPS}" == "1" ]]; then
  if command -v brew >/dev/null 2>&1; then
    ensure_brew_package ffmpeg || echo "Warning: ffmpeg auto-install failed." >&2
  fi
else
  if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "Warning: ffmpeg not found. Install with: brew install ffmpeg" >&2
  fi
fi

if [[ ! -d "/Applications/PRCCamera.app" && ! -d "${HOME}/Applications/PRCCamera.app" ]]; then
  echo "Warning: PRCCamera.app not found. Install/launch PRCCamera and approve the camera extension before enabling camera."
fi

if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete "${PROJECT_ROOT}/" "${TARGET_DIR}/"
else
  rm -rf "${TARGET_DIR}"
  mkdir -p "${TARGET_DIR}"
  cp -a "${PROJECT_ROOT}/." "${TARGET_DIR}/"
fi

if [[ -x "${TARGET_DIR}/macos-audio-driver/scripts/install-driver.sh" ]]; then
  echo "Installing first-party PRCAudio.driver..."
  "${TARGET_DIR}/macos-audio-driver/scripts/install-driver.sh" \
    || echo "Warning: PRCAudio.driver install failed. Run ${TARGET_DIR}/macos-audio-driver/scripts/install-driver.sh manually." >&2
else
  echo "Warning: PRCAudio driver installer script missing at ${TARGET_DIR}/macos-audio-driver/scripts/install-driver.sh" >&2
fi

cat > "${TARGET_DIR}/start.command" <<'START'
#!/usr/bin/env bash
set -euo pipefail
TARGET_DIR="${HOME}/Applications/HostResourceAgent"
LOG_DIR="${HOME}/Library/Logs/HostResourceAgent"
PID_FILE="${LOG_DIR}/host-resource-agent.pid"
RUNTIME_NODE="${TARGET_DIR}/runtime/node/bin/node"
PATH_PREFIX="/opt/homebrew/bin:/usr/local/bin"

if [[ ":${PATH}:" != *":/opt/homebrew/bin:"* || ":${PATH}:" != *":/usr/local/bin:"* ]]; then
  export PATH="${PATH_PREFIX}:${PATH}"
fi
export HOST_BIND="${HOST_BIND:-0.0.0.0}"
unset HOST || true

mkdir -p "${LOG_DIR}"

if [[ -x "${RUNTIME_NODE}" ]]; then
  NODE_BIN="${RUNTIME_NODE}"
elif command -v node >/dev/null 2>&1; then
  NODE_BIN="$(command -v node)"
else
  osascript -e 'display alert "Host Resource Agent" message "Node.js runtime is missing. Reinstall the app package." as critical'
  exit 1
fi

if [[ -f "${PID_FILE}" ]] && kill -0 "$(cat "${PID_FILE}")" >/dev/null 2>&1; then
  open "http://127.0.0.1:8787"
  exit 0
fi

cd "${TARGET_DIR}"
nohup "${NODE_BIN}" linux-app/server.mjs >"${LOG_DIR}/host-resource-agent.log" 2>&1 < /dev/null &
echo $! > "${PID_FILE}"
sleep 1
if ! kill -0 "$(cat "${PID_FILE}")" >/dev/null 2>&1; then
  osascript -e 'display alert "Host Resource Agent" message "Startup failed. Check ~/Library/Logs/HostResourceAgent/host-resource-agent.log." as critical'
  exit 1
fi
open "http://127.0.0.1:8787"
START
chmod +x "${TARGET_DIR}/start.command"

cat > "${TARGET_DIR}/stop.command" <<'STOP'
#!/usr/bin/env bash
set -euo pipefail
PID_FILE="${HOME}/Library/Logs/HostResourceAgent/host-resource-agent.pid"

if [[ ! -f "${PID_FILE}" ]]; then
  exit 0
fi
PID="$(cat "${PID_FILE}")"
if kill -0 "${PID}" >/dev/null 2>&1; then
  kill "${PID}" >/dev/null 2>&1 || true
fi
rm -f "${PID_FILE}"
STOP
chmod +x "${TARGET_DIR}/stop.command"

rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS" "${APP_BUNDLE}/Contents/Resources"
cat > "${APP_BUNDLE}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>CFBundleName</key>
    <string>Host Resource Agent</string>
    <key>CFBundleDisplayName</key>
    <string>Host Resource Agent</string>
    <key>CFBundleExecutable</key>
    <string>host-resource-agent</string>
    <key>CFBundleIdentifier</key>
    <string>org.autobyteus.host-resource-agent</string>
    <key>CFBundleVersion</key>
    <string>0.1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSBackgroundOnly</key>
    <false/>
  </dict>
</plist>
PLIST

cat > "${APP_BUNDLE}/Contents/MacOS/host-resource-agent" <<'BUNDLE'
#!/usr/bin/env bash
set -euo pipefail
exec "${HOME}/Applications/HostResourceAgent/start.command"
BUNDLE
chmod +x "${APP_BUNDLE}/Contents/MacOS/host-resource-agent"

echo "Host Resource Agent installed to ${TARGET_DIR}"
echo "Launch app: ${APP_BUNDLE}"
echo "Start command: ${TARGET_DIR}/start.command"
echo "Stop command: ${TARGET_DIR}/stop.command"
echo "Uninstall script: ${TARGET_DIR}/installers/macos/uninstall.command"
echo "Tip: macOS camera uses PRCCamera extension; mic/speaker use PRCAudio.driver."
