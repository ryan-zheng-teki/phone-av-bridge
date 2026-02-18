#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEAM_ID="${APPLE_TEAM_ID:-7Y86YBQ7B4}"
SCHEME="${SCHEME:-samplecamera}"
CONFIGURATION="${CONFIGURATION:-Debug}"

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

APP_PATH="$(find "${HOME}/Library/Developer/Xcode/DerivedData" -type d -path "*/Build/Products/${CONFIGURATION}/samplecamera.app" | head -n 1)"
if [[ -z "${APP_PATH}" ]]; then
  echo "Build succeeded but app bundle path was not discovered automatically."
  exit 0
fi

echo "Built app: ${APP_PATH}"
echo "To install for activation tests:"
echo "  sudo rm -rf /Applications/PRCCamera.app"
echo "  sudo ditto \"${APP_PATH}\" /Applications/PRCCamera.app"
