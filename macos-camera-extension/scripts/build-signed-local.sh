#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEAM_ID="${APPLE_TEAM_ID:-7Y86YBQ7B4}"
SCHEME="${SCHEME:-samplecamera}"
CONFIGURATION="${CONFIGURATION:-Debug}"
APP_PRODUCT_NAME="${APP_PRODUCT_NAME:-PhoneAVBridgeCamera.app}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-${PROJECT_ROOT}/build}"
CLEAN_FIRST="${CLEAN_FIRST:-1}"
INSTALL_AFTER_BUILD="${INSTALL_AFTER_BUILD:-1}"
INSTALL_TARGET="${INSTALL_TARGET:-${HOME}/Applications/${APP_PRODUCT_NAME}}"
PRUNE_DUPLICATE_CAMERA_BUNDLES="${PRUNE_DUPLICATE_CAMERA_BUNDLES:-1}"

cd "${PROJECT_ROOT}"

if [[ "${CLEAN_FIRST}" == "1" ]]; then
  rm -rf "${DERIVED_DATA_PATH}"
fi

echo "Building ${SCHEME} (${CONFIGURATION}) for team ${TEAM_ID}..."
xcodebuild \
  -project samplecamera.xcodeproj \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  DEVELOPMENT_TEAM="${TEAM_ID}" \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  build

APP_PATH="${DERIVED_DATA_PATH}/Build/Products/${CONFIGURATION}/${APP_PRODUCT_NAME}"
if [[ ! -d "${APP_PATH}" ]]; then
  echo "Build succeeded but app bundle path was not found: ${APP_PATH}" >&2
  exit 1
fi

echo "Built app: ${APP_PATH}"
if [[ "${INSTALL_AFTER_BUILD}" == "1" ]]; then
  SOURCE_APP="${APP_PATH}" \
  TARGET_APP="${INSTALL_TARGET}" \
  PRUNE_DUPLICATE_CAMERA_BUNDLES="${PRUNE_DUPLICATE_CAMERA_BUNDLES}" \
    "${SCRIPT_DIR}/install-local-app.sh"
else
  echo "Install skipped (INSTALL_AFTER_BUILD=0)."
  echo "To install manually:"
  echo "  SOURCE_APP=\"${APP_PATH}\" TARGET_APP=\"${INSTALL_TARGET}\" ${SCRIPT_DIR}/install-local-app.sh"
fi
