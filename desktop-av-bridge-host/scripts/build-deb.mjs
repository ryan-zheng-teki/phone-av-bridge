import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const execFileAsync = promisify(execFile);
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const projectRoot = path.resolve(__dirname, '..');
const repoRoot = path.resolve(projectRoot, '..');
const distDir = path.join(projectRoot, 'dist');

async function ensureExecutable(filePath) {
  await fs.chmod(filePath, 0o755);
}

async function buildDeb() {
  await fs.mkdir(distDir, { recursive: true });

  const packageJsonPath = path.join(projectRoot, 'package.json');
  const packageJson = JSON.parse(await fs.readFile(packageJsonPath, 'utf8'));
  const version = packageJson.version || '0.1.0';

  const { stdout: archStdout } = await execFileAsync('dpkg', ['--print-architecture']);
  const arch = archStdout.trim() || 'amd64';
  const stamp = new Date().toISOString().replace(/[:.]/g, '-');

  const stageRoot = path.join(distDir, `deb-stage-${stamp}`);
  const pkgRoot = path.join(stageRoot, 'pkg');
  const debianDir = path.join(pkgRoot, 'DEBIAN');
  const appRoot = path.join(pkgRoot, 'opt', 'phone-av-bridge-host');
  const binDir = path.join(pkgRoot, 'usr', 'bin');
  const desktopDir = path.join(pkgRoot, 'usr', 'share', 'applications');
  const debPath = path.join(distDir, `phone-av-bridge-host_${version}_${arch}.deb`);

  await fs.rm(stageRoot, { recursive: true, force: true });
  await fs.mkdir(debianDir, { recursive: true });
  await fs.mkdir(appRoot, { recursive: true });
  await fs.mkdir(binDir, { recursive: true });
  await fs.mkdir(desktopDir, { recursive: true });

  await execFileAsync('node', [path.join(projectRoot, 'scripts', 'prepare-runtime.mjs')], {
    cwd: projectRoot,
  });

  const hostArtifacts = [
    'package.json',
    'package-lock.json',
    'README.md',
    'core',
    'adapters',
    'desktop-app',
    'installers',
    'scripts',
    'runtime',
  ];
  for (const artifact of hostArtifacts) {
    await fs.cp(path.join(projectRoot, artifact), path.join(appRoot, artifact), { recursive: true });
  }

  const bridgeRuntimeSource = path.join(repoRoot, 'phone-av-camera-bridge-runtime');
  const bridgeRuntimeTarget = path.join(appRoot, 'phone-av-camera-bridge-runtime');
  await fs.cp(bridgeRuntimeSource, bridgeRuntimeTarget, { recursive: true });

  await execFileAsync('npm', ['ci', '--omit=dev', '--ignore-scripts', '--no-audit', '--no-fund'], {
    cwd: appRoot,
  });

  const control = [
    'Package: phone-av-bridge-host',
    `Version: ${version}`,
    'Section: video',
    'Priority: optional',
    `Architecture: ${arch}`,
    'Maintainer: AutoByteus <support@autobyteus.com>',
    'Depends: bash, ffmpeg, pulseaudio-utils, v4l2loopback-dkms',
    'Recommends: v4l2loopback-utils',
    'Description: AutoByteus Phone AV Bridge Host',
    ' Exposes Android phone camera/microphone/speaker as host virtual devices.',
    ' Includes Linux host UI at http://127.0.0.1:8787 after launch.',
    '',
  ].join('\n');
  await fs.writeFile(path.join(debianDir, 'control'), control, 'utf8');

  const postinstScript = `#!/usr/bin/env bash
set -euo pipefail

VIDEO_NR="\${V4L2_VIDEO_NR:-2}"
CARD_LABEL="\${V4L2_CARD_LABEL:-AutoByteusPhoneCamera}"
MODPROBE_CONF="/etc/modprobe.d/phone-av-bridge-v4l2loopback.conf"
MODULES_LOAD_CONF="/etc/modules-load.d/phone-av-bridge-v4l2loopback.conf"
DEFAULTS_FILE="/etc/default/phone-av-bridge-host"

mkdir -p /etc/modprobe.d /etc/modules-load.d
printf 'options v4l2loopback video_nr=%s card_label=%s exclusive_caps=0 max_buffers=2\\n' "\${VIDEO_NR}" "\${CARD_LABEL}" > "\${MODPROBE_CONF}" || true
printf 'v4l2loopback\\n' > "\${MODULES_LOAD_CONF}" || true

if [[ ! -f "\${DEFAULTS_FILE}" ]]; then
  cat > "\${DEFAULTS_FILE}" <<'DEFAULTS'
# Phone AV Bridge host defaults (optional overrides)
LINUX_CAMERA_MODE=compatibility
V4L2_DEVICE=/dev/video2
# Optional: pin speaker capture source instead of automatic safe selection.
# LINUX_SPEAKER_CAPTURE_SOURCE=alsa_output.pci-0000_00_1f.3.analog-stereo.monitor
DEFAULTS
fi

if command -v modprobe >/dev/null 2>&1; then
  modprobe -r v4l2loopback || true
  modprobe v4l2loopback video_nr="\${VIDEO_NR}" card_label="\${CARD_LABEL}" exclusive_caps=0 max_buffers=2 || true
fi
`;
  const prermScript = `#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="/opt/phone-av-bridge-host"

kill_tree() {
  local pid="$1"
  local child
  for child in $(pgrep -P "\${pid}" 2>/dev/null || true); do
    kill_tree "\${child}"
  done
  kill "\${pid}" >/dev/null 2>&1 || true
}

for host_pid in $(pgrep -f "\${TARGET_DIR}/desktop-app/server.mjs" 2>/dev/null || true); do
  kill_tree "\${host_pid}"
done

for bridge_pid in $(pgrep -f "\${TARGET_DIR}/phone-av-camera-bridge-runtime/bin/run-bridge.sh" 2>/dev/null || true); do
  kill_tree "\${bridge_pid}"
done

for mic_pid in $(pgrep -f 'ffmpeg .* -f pulse phone_av_bridge_mic_sink_' 2>/dev/null || true); do
  kill "\${mic_pid}" >/dev/null 2>&1 || true
done

if command -v pactl >/dev/null 2>&1; then
  { pactl list short modules 2>/dev/null || true; } | awk -F'\\t' '/phone_av_bridge_mic_sink_|phone_av_bridge_mic_input_/ {print $1}' | while read -r module_id; do
    if [[ -n "\${module_id}" ]]; then
      pactl unload-module "\${module_id}" >/dev/null 2>&1 || true
    fi
  done
fi
`;
  const postrmScript = `#!/usr/bin/env bash
set -euo pipefail

if [[ "\${1:-}" == "remove" || "\${1:-}" == "purge" ]]; then
  if command -v modprobe >/dev/null 2>&1; then
    modprobe -r v4l2loopback >/dev/null 2>&1 || true
  fi
fi

if [[ "\${1:-}" == "purge" ]]; then
  rm -f /etc/modules-load.d/phone-av-bridge-v4l2loopback.conf || true
  rm -f /etc/modprobe.d/phone-av-bridge-v4l2loopback.conf || true
  rm -f /etc/default/phone-av-bridge-host || true
fi
`;
  await fs.writeFile(path.join(debianDir, 'postinst'), postinstScript, 'utf8');
  await fs.writeFile(path.join(debianDir, 'prerm'), prermScript, 'utf8');
  await fs.writeFile(path.join(debianDir, 'postrm'), postrmScript, 'utf8');
  await ensureExecutable(path.join(debianDir, 'postinst'));
  await ensureExecutable(path.join(debianDir, 'prerm'));
  await ensureExecutable(path.join(debianDir, 'postrm'));

  const startScript = `#!/usr/bin/env bash
set -euo pipefail
APP_ROOT="/opt/phone-av-bridge-host"
LOG_DIR="\${HOME}/.local/state/phone-av-bridge-host"
PID_FILE="\${LOG_DIR}/phone-av-bridge-host.pid"
RUNTIME_NODE="\${APP_ROOT}/runtime/node/bin/node"

mkdir -p "\${LOG_DIR}"

assert_packaged_node_dependencies() {
  local missing=()
  local module_name
  for module_name in qrcode ws; do
    if [[ ! -f "\${APP_ROOT}/node_modules/\${module_name}/package.json" ]]; then
      missing+=("\${module_name}")
    fi
  done
  if (( \${#missing[@]} > 0 )); then
    echo "Phone AV Bridge Host package is incomplete: missing Node dependencies (\${missing[*]})." >&2
    echo "Reinstall a fixed .deb package, or run: sudo npm --prefix \${APP_ROOT} install --omit=dev" >&2
    exit 1
  fi
}

if [[ -x "\${RUNTIME_NODE}" ]] && "\${RUNTIME_NODE}" --version >/dev/null 2>&1; then
  NODE_BIN="\${RUNTIME_NODE}"
elif command -v node >/dev/null 2>&1; then
  NODE_BIN="$(command -v node)"
else
  echo "Phone AV Bridge Host cannot start because Node.js runtime is unavailable." >&2
  exit 1
fi

export LINUX_CAMERA_MODE="\${LINUX_CAMERA_MODE:-compatibility}"
export V4L2_DEVICE="\${V4L2_DEVICE:-/dev/video2}"
assert_packaged_node_dependencies

if [[ -f "\${PID_FILE}" ]] && kill -0 "$(cat "\${PID_FILE}")" >/dev/null 2>&1; then
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "http://127.0.0.1:8787" >/dev/null 2>&1 || true
  fi
  exit 0
fi

cd "\${APP_ROOT}"
"\${NODE_BIN}" desktop-app/server.mjs >"\${LOG_DIR}/phone-av-bridge-host.log" 2>&1 &
echo $! > "\${PID_FILE}"
sleep 1
if ! kill -0 "$(cat "\${PID_FILE}")" >/dev/null 2>&1; then
  echo "Phone AV Bridge Host failed to start. Check \${LOG_DIR}/phone-av-bridge-host.log" >&2
  exit 1
fi
if command -v xdg-open >/dev/null 2>&1; then
  xdg-open "http://127.0.0.1:8787" >/dev/null 2>&1 || true
fi
`;
  const stopScript = `#!/usr/bin/env bash
set -euo pipefail
PID_FILE="\${HOME}/.local/state/phone-av-bridge-host/phone-av-bridge-host.pid"

if [[ ! -f "\${PID_FILE}" ]]; then
  exit 0
fi

PID="$(cat "\${PID_FILE}")"
if kill -0 "\${PID}" >/dev/null 2>&1; then
  kill "\${PID}" >/dev/null 2>&1 || true
fi
rm -f "\${PID_FILE}"
`;
  const enableCameraScript = `#!/usr/bin/env bash
set -euo pipefail
VIDEO_NR="\${V4L2_VIDEO_NR:-2}"
CARD_LABEL="\${V4L2_CARD_LABEL:-AutoByteusPhoneCamera}"

if [[ "\${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Run with sudo: sudo phone-av-bridge-host-enable-camera" >&2
  exit 1
fi

mkdir -p /etc/modprobe.d /etc/modules-load.d
printf 'options v4l2loopback video_nr=%s card_label=%s exclusive_caps=0 max_buffers=2\\n' "\${VIDEO_NR}" "\${CARD_LABEL}" > /etc/modprobe.d/phone-av-bridge-v4l2loopback.conf
printf 'v4l2loopback\\n' > /etc/modules-load.d/phone-av-bridge-v4l2loopback.conf
modprobe -r v4l2loopback || true
modprobe v4l2loopback video_nr="\${VIDEO_NR}" card_label="\${CARD_LABEL}" exclusive_caps=0 max_buffers=2
echo "v4l2loopback loaded at /dev/video\${VIDEO_NR} with label \${CARD_LABEL}"
`;
  const desktopFile = `[Desktop Entry]
Type=Application
Name=Phone AV Bridge Host
Exec=phone-av-bridge-host-start
Terminal=false
Categories=AudioVideo;Network;
`;

  const startPath = path.join(binDir, 'phone-av-bridge-host-start');
  const stopPath = path.join(binDir, 'phone-av-bridge-host-stop');
  const enableCameraPath = path.join(binDir, 'phone-av-bridge-host-enable-camera');
  await fs.writeFile(startPath, startScript, 'utf8');
  await fs.writeFile(stopPath, stopScript, 'utf8');
  await fs.writeFile(enableCameraPath, enableCameraScript, 'utf8');
  await ensureExecutable(startPath);
  await ensureExecutable(stopPath);
  await ensureExecutable(enableCameraPath);

  await fs.writeFile(path.join(desktopDir, 'phone-av-bridge-host.desktop'), desktopFile, 'utf8');

  await execFileAsync('dpkg-deb', ['--build', '--root-owner-group', pkgRoot, debPath]);
  await fs.rm(stageRoot, { recursive: true, force: true });
  console.log(`deb package created: ${debPath}`);
}

buildDeb().catch((error) => {
  console.error(`failed to build deb package: ${error.message}`);
  process.exit(1);
});
