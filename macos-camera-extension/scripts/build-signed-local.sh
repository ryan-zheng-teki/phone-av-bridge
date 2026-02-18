#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEAM_ID="${APPLE_TEAM_ID:-7Y86YBQ7B4}"
SCHEME="${SCHEME:-samplecamera}"
CONFIGURATION="${CONFIGURATION:-Debug}"
APP_PRODUCT_NAME="${APP_PRODUCT_NAME:-PhoneAVBridgeCamera.app}"

cd "${PROJECT_ROOT}"

echo "Building ${SCHEME} (${CONFIGURATION}) for team ${TEAM_ID}..."
xcodebuild \
  -project samplecamera.xcodeproj \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  DEVELOPMENT_TEAM="${TEAM_ID}" \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  build

APP_PATH="$(
  find "${HOME}/Library/Developer/Xcode/DerivedData" \
    -type d \
    -path "*/Build/Products/${CONFIGURATION}/${APP_PRODUCT_NAME}" \
    -exec stat -f '%m %N' {} \; \
    | sort -nr \
    | head -n 1 \
    | cut -d ' ' -f2-
)"
if [[ -z "${APP_PATH}" ]]; then
  echo "Build succeeded but app bundle path was not discovered automatically."
  exit 0
fi

echo "Built app: ${APP_PATH}"
echo "To install for activation tests:"
echo "  sudo rm -rf /Applications/PhoneAVBridgeCamera.app"
echo "  sudo ditto \"${APP_PATH}\" /Applications/PhoneAVBridgeCamera.app"
