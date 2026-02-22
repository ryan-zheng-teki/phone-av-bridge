#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST_DIR="${REPO_ROOT}/desktop-av-bridge-host"
DIST_DIR="${HOST_DIR}/dist"

PATH_FIX='export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"'
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"
hash -r

log() {
  printf '[wsl-setup] %s\n' "$*"
}

fail() {
  printf '[wsl-setup] error: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

if ! grep -qiE 'microsoft|wsl' /proc/version; then
  fail 'this script is intended for WSL only'
fi

need_cmd sudo
need_cmd apt
need_cmd dpkg
need_cmd node
need_cmd npm
need_cmd curl
need_cmd ip

if ! grep -Fq "$PATH_FIX" "$HOME/.bashrc" 2>/dev/null; then
  log 'persisting PATH fix to ~/.bashrc'
  printf '\n%s\n' "$PATH_FIX" >> "$HOME/.bashrc"
fi

log 'installing WSL prerequisites (apt)'
sudo apt update
sudo apt install -y \
  ffmpeg pulseaudio-utils curl jq \
  python3-pip python3.12-venv \
  rsync

VERSION="$(node -p "require('${HOST_DIR}/package.json').version")"
ARCH="$(dpkg --print-architecture)"
DEB_NAME="phone-av-bridge-host_${VERSION}_${ARCH}.deb"
DEB_PATH="${DIST_DIR}/${DEB_NAME}"

mkdir -p "$DIST_DIR"

if [[ ! -f "$DEB_PATH" ]]; then
  log "building Debian package ${DEB_NAME} in Linux-native workspace"
  BUILD_ROOT="$HOME/.cache/phone-av-bridge-build"
  BUILD_REPO="$BUILD_ROOT/phone-av-bridge"
  rm -rf "$BUILD_REPO"
  mkdir -p "$BUILD_ROOT"
  rsync -a --delete "$REPO_ROOT/" "$BUILD_REPO/"
  (
    cd "$BUILD_REPO/desktop-av-bridge-host"
    npm run -s build:deb
  )
  cp -f "$BUILD_REPO/desktop-av-bridge-host/dist/${DEB_NAME}" "$DEB_PATH"
else
  log "using existing Debian package ${DEB_PATH}"
fi

log 'installing host Debian package'
sudo apt install -y "$DEB_PATH"

WSL_IP="$(ip -4 -o addr show eth0 | awk '{print $4}' | cut -d/ -f1)"
WIN_LAN_IP=''
if command -v powershell.exe >/dev/null 2>&1; then
  WIN_LAN_IP="$(powershell.exe -NoProfile -Command 'Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch "vEthernet|Loopback|WSL" -and $_.IPAddress -notlike "169.254*" } | Select-Object -ExpandProperty IPAddress | Select-Object -First 1' | tr -d '\r')"
fi

mkdir -p "$HOME/.local/bin"

cat > "$HOME/.local/bin/phone-av-bridge-host-start-wsl" <<EOS
#!/usr/bin/env bash
set -euo pipefail
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:\${PATH:-}"
HOST_BIND=0.0.0.0 ADVERTISED_HOST=${WIN_LAN_IP:-$WSL_IP} PORT=8787 /usr/bin/phone-av-bridge-host-start
EOS
chmod +x "$HOME/.local/bin/phone-av-bridge-host-start-wsl"

cat > "$HOME/.local/bin/phone-av-bridge-host-stop-wsl" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"
/usr/bin/phone-av-bridge-host-stop
EOS
chmod +x "$HOME/.local/bin/phone-av-bridge-host-stop-wsl"

log 'starting host with WSL helper'
"$HOME/.local/bin/phone-av-bridge-host-start-wsl"
sleep 2

log 'health check'
curl -sS http://127.0.0.1:8787/health
printf '\n'
log 'bootstrap check'
curl -sS http://127.0.0.1:8787/api/bootstrap
printf '\n'

cat <<MSG

WSL setup completed.

Local helper commands:
  ${HOME}/.local/bin/phone-av-bridge-host-start-wsl
  ${HOME}/.local/bin/phone-av-bridge-host-stop-wsl

Detected network values:
  Windows LAN IP: ${WIN_LAN_IP:-<not-detected>}
  WSL eth0 IP:    ${WSL_IP}

Important for phone-on-LAN access to WSL host:
  Run these in Windows PowerShell (Run as Administrator):

  netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=8787
  netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=8787 connectaddress=${WSL_IP} connectport=8787
  netsh advfirewall firewall add rule name="PhoneAVBridge 8787" dir=in action=allow protocol=TCP localport=8787

After portproxy, pair phone via QR at:
  http://${WIN_LAN_IP:-<WINDOWS_LAN_IP>}:8787

Note: host auto-discovery list may still miss WSL host because discovery uses UDP (39888).
Use QR pairing for WSL + portproxy flow.
MSG
