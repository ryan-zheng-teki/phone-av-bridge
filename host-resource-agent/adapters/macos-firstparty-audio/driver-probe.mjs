import fs from 'node:fs/promises';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

const execFileAsync = promisify(execFile);

export const DEFAULT_DRIVER_BUNDLE_PATH = '/Library/Audio/Plug-Ins/HAL/PRCAudio.driver';
export const DEFAULT_DRIVER_DEVICE_NAME = 'PRCAudio 2ch';

export async function driverBundleExists(path = DEFAULT_DRIVER_BUNDLE_PATH) {
  try {
    await fs.access(path);
    return true;
  } catch {
    return false;
  }
}

export function parseFfmpegAvfoundationDeviceList(stderr = '') {
  const devices = {
    video: [],
    audio: [],
  };

  const lines = String(stderr || '').split('\n');
  let section = null;
  const pattern = /\[AVFoundation indev @ .*] \[([0-9]+)\]\s+(.+)/;

  for (const line of lines) {
    if (line.includes('AVFoundation video devices:')) {
      section = 'video';
      continue;
    }
    if (line.includes('AVFoundation audio devices:')) {
      section = 'audio';
      continue;
    }
    if (!section) {
      continue;
    }

    const match = line.match(pattern);
    if (!match) {
      continue;
    }

    devices[section].push({
      index: Number.parseInt(match[1], 10),
      name: match[2].trim(),
    });
  }

  return devices;
}

export async function listAvfoundationDevices() {
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

  return parseFfmpegAvfoundationDeviceList(stderr);
}

export async function probePrcAudioDriver({ expectedDeviceName = DEFAULT_DRIVER_DEVICE_NAME } = {}) {
  const [bundleExists, devices] = await Promise.all([
    driverBundleExists(),
    listAvfoundationDevices(),
  ]);

  const visible = devices.audio.some((device) =>
    device.name.toLowerCase().includes(expectedDeviceName.toLowerCase())
  );

  return {
    bundleExists,
    visible,
    devices,
  };
}
