import { execFile } from 'node:child_process';
import fs from 'node:fs/promises';
import net from 'node:net';
import { promisify } from 'node:util';
import { probePhoneAvBridgeAudioDriver } from '../adapters/macos-firstparty-audio/driver-probe.mjs';

const execFileAsync = promisify(execFile);

async function commandExists(command) {
  try {
    await execFileAsync('which', [command]);
    return true;
  } catch {
    return false;
  }
}

async function linuxModuleLoaded(moduleName) {
  try {
    const { stdout } = await execFileAsync('sh', ['-c', `lsmod | grep -E '^${moduleName}\\b'`]);
    return stdout.trim().length > 0;
  } catch {
    return false;
  }
}

async function pathExists(path) {
  try {
    await fs.access(path);
    return true;
  } catch {
    return false;
  }
}

async function listAvfoundationVideoDevices() {
  let stderr = '';
  try {
    const result = await execFileAsync('ffmpeg', [
      '-hide_banner',
      '-f',
      'avfoundation',
      '-list_devices',
      'true',
      '-i',
      '',
    ]);
    stderr = result.stderr || '';
  } catch (error) {
    stderr = error?.stderr || '';
  }

  const devices = [];
  let inVideoSection = false;
  const lines = stderr.split('\n');
  const pattern = /\[AVFoundation indev @ .*] \[([0-9]+)\]\s+(.+)/;
  for (const line of lines) {
    if (line.includes('AVFoundation video devices:')) {
      inVideoSection = true;
      continue;
    }
    if (line.includes('AVFoundation audio devices:')) {
      inVideoSection = false;
      continue;
    }
    if (!inVideoSection) continue;

    const match = line.match(pattern);
    if (!match) continue;
    devices.push({
      index: Number.parseInt(match[1], 10),
      name: match[2].trim(),
    });
  }
  return devices;
}

async function extensionStatus(bundleId) {
  try {
    const { stdout } = await execFileAsync('systemextensionsctl', ['list']);
    const line = stdout
      .split('\n')
      .find((entry) => entry.includes(bundleId));
    if (!line) {
      return 'missing';
    }
    const normalized = line.toLowerCase();
    if (normalized.includes('activated enabled')) {
      return 'enabled';
    }
    if (normalized.includes('activated waiting')) {
      return 'waiting_for_user';
    }
    return 'present';
  } catch {
    return 'unknown';
  }
}

async function tcpPortReachable(host, port, timeoutMs = 700) {
  return new Promise((resolve) => {
    let done = false;
    const socket = net.createConnection({ host, port: Number(port) });
    const finalize = (result) => {
      if (done) {
        return;
      }
      done = true;
      socket.destroy();
      resolve(result);
    };
    socket.setTimeout(timeoutMs);
    socket.once('connect', () => finalize(true));
    socket.once('timeout', () => finalize(false));
    socket.once('error', () => finalize(false));
  });
}

function checkResult(id, label, status, detail, remediation = null) {
  return { id, label, status, detail, remediation };
}

export async function runPreflight(platform = process.platform) {
  const checks = [];

  const ffmpegOk = await commandExists('ffmpeg');
  checks.push(
    checkResult(
      'ffmpeg',
      'FFmpeg available',
      ffmpegOk ? 'pass' : 'fail',
      ffmpegOk ? 'FFmpeg is installed.' : 'FFmpeg is not installed.',
      ffmpegOk ? null : 'Install FFmpeg with your package manager and rerun preflight.'
    )
  );

  if (platform === 'linux') {
    const cameraMode = (process.env.LINUX_CAMERA_MODE || 'compatibility').toLowerCase();
    const v4l2Device = process.env.V4L2_DEVICE || '/dev/video2';
    const compatibilityRequested = cameraMode === 'compatibility';
    const autoMode = cameraMode === 'auto';
    const userspaceMode = cameraMode === 'userspace';

    checks.push(
      checkResult(
        'linux_camera_mode',
        'Linux camera mode',
        'pass',
        userspaceMode
          ? 'userspace mode selected (no kernel camera module required).'
          : autoMode
            ? 'auto mode selected (uses v4l2 device when available, userspace ingest otherwise).'
            : 'compatibility mode selected (v4l2 loopback expected).',
        null
      )
    );

    const v4l2loopbackLoaded = await linuxModuleLoaded('v4l2loopback');
    const v4l2DevicePresent = await pathExists(v4l2Device);
    const v4l2Required = compatibilityRequested || (autoMode && v4l2DevicePresent);
    const v4l2Status = userspaceMode ? 'pass' : v4l2Required ? (v4l2loopbackLoaded ? 'pass' : 'warn') : 'pass';
    const v4l2Detail = userspaceMode
      ? 'Kernel camera module is optional in userspace mode.'
      : v4l2Required
        ? v4l2loopbackLoaded
          ? 'v4l2loopback kernel module appears loaded.'
          : 'v4l2loopback kernel module not detected.'
        : 'v4l2loopback is optional in current auto-mode state.';
    checks.push(
      checkResult(
        'v4l2loopback',
        'Linux virtual camera module',
        v4l2Status,
        v4l2Detail,
        v4l2Status === 'warn' ? 'Enable compatibility camera mode and install/load v4l2loopback for webcam exposure.' : null
      )
    );

    const pactlOk = await commandExists('pactl');
    const pwCliOk = await commandExists('pw-cli');
    checks.push(
      checkResult(
        'linux_audio_backend',
        'Linux audio tooling',
        pactlOk || pwCliOk ? 'pass' : 'warn',
        pactlOk || pwCliOk
          ? 'PulseAudio/PipeWire tooling detected.'
          : 'No PulseAudio/PipeWire CLI tooling detected.',
        pactlOk || pwCliOk ? null : 'Install PipeWire or PulseAudio user tooling for virtual mic/speaker routing.'
      )
    );
  } else if (platform === 'darwin') {
    const cameraExtensionState = await extensionStatus('org.autobyteus.phoneavbridge.camera.extension');
    checks.push(
      checkResult(
        'macos_camera_extension_state',
        'Phone AV Bridge Camera extension state',
        cameraExtensionState === 'enabled' ? 'pass' : 'warn',
        cameraExtensionState === 'enabled'
          ? 'Phone AV Bridge Camera extension is activated and enabled.'
          : cameraExtensionState === 'waiting_for_user'
            ? 'Phone AV Bridge Camera extension is activated but waiting for user approval.'
            : cameraExtensionState === 'missing'
              ? 'Phone AV Bridge Camera extension is not installed.'
              : 'Phone AV Bridge Camera extension status could not be confirmed.',
        cameraExtensionState === 'enabled'
          ? null
          : 'Install/open PhoneAVBridgeCamera.app and approve it under System Settings -> General -> Login Items & Extensions -> Camera Extensions.'
      )
    );

    const videoDevices = await listAvfoundationVideoDevices();
    const phoneAvBridgeCameraVisible = videoDevices.some((device) =>
      device.name.toLowerCase().includes('phone av bridge camera')
    );
    checks.push(
      checkResult(
        'macos_virtual_camera_visible',
        'Phone AV Bridge Camera visible to capture APIs',
        phoneAvBridgeCameraVisible ? 'pass' : 'warn',
        phoneAvBridgeCameraVisible
          ? 'Phone AV Bridge Camera appears in AVFoundation video device list.'
          : 'Phone AV Bridge Camera is not visible in AVFoundation video device list.',
        phoneAvBridgeCameraVisible
          ? null
          : 'Open PhoneAVBridgeCamera.app, keep it running, then restart capture apps and rerun preflight.'
      )
    );

    const frameServerReady = await tcpPortReachable(
      process.env.MACOS_CAMERA_FRAME_HOST || '127.0.0.1',
      Number(process.env.MACOS_CAMERA_FRAME_PORT || 39501)
    );
    checks.push(
      checkResult(
        'macos_camera_frame_server',
        'Phone AV Bridge Camera frame server',
        frameServerReady ? 'pass' : 'warn',
        frameServerReady
          ? 'Phone AV Bridge Camera frame server is listening on local TCP port 39501.'
          : 'Phone AV Bridge Camera frame server is not reachable on local TCP port 39501.',
        frameServerReady
          ? null
          : 'Open PhoneAVBridgeCamera.app and verify extension approval before enabling camera on Android.'
      )
    );

    const audioDriverProbe = await probePhoneAvBridgeAudioDriver({
      expectedDeviceName: process.env.MACOS_AUDIO_OUTPUT_DEVICE || 'PhoneAVBridgeAudio 2ch',
    });
    checks.push(
      checkResult(
        'macos_phone_av_bridge_audio_driver_bundle',
        'Phone AV Bridge Audio driver bundle installed',
        audioDriverProbe.bundleExists ? 'pass' : 'warn',
        audioDriverProbe.bundleExists
          ? 'PhoneAVBridgeAudio.driver is installed under /Library/Audio/Plug-Ins/HAL.'
          : 'PhoneAVBridgeAudio.driver bundle not found.',
        audioDriverProbe.bundleExists
          ? null
          : 'Run: desktop-av-bridge-host/macos-audio-driver/scripts/install-driver.sh'
      )
    );

    checks.push(
      checkResult(
        'macos_phone_av_bridge_audio_device_visible',
        'Phone AV Bridge Audio virtual audio device visible',
        audioDriverProbe.visible ? 'pass' : 'warn',
        audioDriverProbe.visible
          ? `Virtual audio device "${process.env.MACOS_AUDIO_OUTPUT_DEVICE || 'PhoneAVBridgeAudio 2ch'}" appears in capture APIs.`
          : `Virtual audio device "${process.env.MACOS_AUDIO_OUTPUT_DEVICE || 'PhoneAVBridgeAudio 2ch'}" not visible in capture APIs.`,
        audioDriverProbe.visible
          ? null
          : 'Restart coreaudiod and reopen meeting/capture apps after installing PhoneAVBridgeAudio.driver.'
      )
    );

    checks.push(
      checkResult(
        'macos_host_audio_mode',
        'macOS host audio mode',
        audioDriverProbe.bundleExists && audioDriverProbe.visible ? 'pass' : 'warn',
        'This build uses Phone AV Bridge Camera extension + first-party Phone AV Bridge Audio driver for macOS media routing.',
        audioDriverProbe.bundleExists && audioDriverProbe.visible
          ? null
          : 'Install PhoneAVBridgeAudio.driver and verify visibility before enabling microphone/speaker toggles.'
      )
    );
  } else {
    checks.push(
      checkResult(
        'platform_support',
        'Supported platform',
        'warn',
        `Platform ${platform} is not primary target for this release.`,
        'Use Linux or macOS host for supported flow.'
      )
    );
  }

  const hasFail = checks.some((check) => check.status === 'fail');
  const hasWarn = checks.some((check) => check.status === 'warn');

  return {
    platform,
    status: hasFail ? 'needs_attention' : hasWarn ? 'ready_with_notes' : 'ready',
    checks,
    generatedAt: new Date().toISOString(),
  };
}
