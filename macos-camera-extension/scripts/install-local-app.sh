#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_PRODUCT_NAME="${APP_PRODUCT_NAME:-PhoneAVBridgeCamera.app}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SOURCE_APP="${SOURCE_APP:-${PROJECT_ROOT}/build/Build/Products/${CONFIGURATION}/${APP_PRODUCT_NAME}}"
TARGET_APP="${TARGET_APP:-${HOME}/Applications/${APP_PRODUCT_NAME}}"
OPEN_AFTER_INSTALL="${OPEN_AFTER_INSTALL:-1}"
PRUNE_DUPLICATE_CAMERA_BUNDLES="${PRUNE_DUPLICATE_CAMERA_BUNDLES:-1}"

if [[ ! -d "${SOURCE_APP}" ]]; then
  echo "Source app not found: ${SOURCE_APP}" >&2
  exit 1
fi

TARGET_DIR="$(dirname "${TARGET_APP}")"
mkdir -p "${TARGET_DIR}"

# Ensure the running app process does not lock stale binaries.
pkill -f 'PhoneAVBridgeCamera.app/Contents/MacOS/PhoneAVBridgeCamera' >/dev/null 2>&1 || true

rm -rf "${TARGET_APP}"
cp -R "${SOURCE_APP}" "${TARGET_APP}"
xattr -dr com.apple.quarantine "${TARGET_APP}" >/dev/null 2>&1 || true

if [[ "${PRUNE_DUPLICATE_CAMERA_BUNDLES}" == "1" ]]; then
  CANONICAL_USER_APP="${HOME}/Applications/${APP_PRODUCT_NAME}"
  CANONICAL_SYSTEM_APP="/Applications/${APP_PRODUCT_NAME}"

  if [[ "${TARGET_APP}" != "${CANONICAL_USER_APP}" ]]; then
    rm -rf "${CANONICAL_USER_APP}" >/dev/null 2>&1 || true
  fi
  if [[ "${TARGET_APP}" != "${CANONICAL_SYSTEM_APP}" ]]; then
    rm -rf "${CANONICAL_SYSTEM_APP}" >/dev/null 2>&1 || true
  fi

  find "/Applications" -maxdepth 1 -type d -name 'PhoneAVBridgeCamera.backup*.app' -exec rm -rf {} + >/dev/null 2>&1 || true
  find "${HOME}/Applications" -maxdepth 1 -type d -name 'PhoneAVBridgeCamera.backup*.app' -exec rm -rf {} + >/dev/null 2>&1 || true
fi

echo "Installed app: ${TARGET_APP}"

if [[ "${OPEN_AFTER_INSTALL}" == "1" ]]; then
  open "${TARGET_APP}"
  echo "Launched app: ${TARGET_APP}"
fi
