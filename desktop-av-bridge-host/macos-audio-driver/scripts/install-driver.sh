#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCE_BUNDLE="${ROOT_DIR}/PhoneAVBridgeAudio.driver"
TARGET_DIR="/Library/Audio/Plug-Ins/HAL"
TARGET_BUNDLE="${TARGET_DIR}/PhoneAVBridgeAudio.driver"
ESCALATED_FLAG="${1:-}"

if [[ ! -d "${SOURCE_BUNDLE}" ]]; then
  echo "PhoneAVBridgeAudio.driver bundle not found at ${SOURCE_BUNDLE}" >&2
  exit 1
fi
if [[ ! -x "${SOURCE_BUNDLE}/Contents/MacOS/PhoneAVBridgeAudio" ]]; then
  echo "Phone AV Bridge Audio executable missing at ${SOURCE_BUNDLE}/Contents/MacOS/PhoneAVBridgeAudio" >&2
  exit 1
fi

if [[ "${EUID}" -ne 0 && "${ESCALATED_FLAG}" != "--as-root" && ! -t 0 ]]; then
  escaped_cmd=$(printf '%q ' "$0" --as-root)
  osascript -e "do shell script \"${escaped_cmd}\" with administrator privileges"
  exit 0
fi

copy_with_privilege() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

copy_with_privilege mkdir -p "${TARGET_DIR}"
if copy_with_privilege test -d "${TARGET_BUNDLE}"; then
  copy_with_privilege rm -rf "${TARGET_BUNDLE}"
fi
copy_with_privilege cp -R "${SOURCE_BUNDLE}" "${TARGET_BUNDLE}"
copy_with_privilege chmod 755 "${TARGET_BUNDLE}/Contents/MacOS/PhoneAVBridgeAudio"

echo "Installed PhoneAVBridgeAudio.driver to ${TARGET_BUNDLE}"
echo "Restarting coreaudiod to reload device registration..."
if [[ "${EUID}" -eq 0 ]]; then
  killall -9 coreaudiod || true
else
  sudo killall -9 coreaudiod || true
fi

echo "Done."
