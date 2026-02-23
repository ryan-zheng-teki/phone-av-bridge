#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SCHEME="${SCHEME:-PhoneAVBridgeIOSApp}"
CONFIGURATION="${CONFIGURATION:-Release}"
APP_PRODUCT_NAME="${APP_PRODUCT_NAME:-PhoneAVBridgeIOSApp.app}"
VERSION_SUFFIX="${RELEASE_VERSION:-${VERSION_SUFFIX:-local}}"
DIST_DIR="${PROJECT_ROOT}/dist"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-${PROJECT_ROOT}/build_release_ios_sim}"
CLEAN_FIRST="${CLEAN_FIRST:-1}"

cd "${PROJECT_ROOT}"

if [[ "${CLEAN_FIRST}" == "1" ]]; then
  rm -rf "${DERIVED_DATA_PATH}"
fi

echo "Building unsigned iOS simulator app ${SCHEME} (${CONFIGURATION})..."
xcodebuild \
  -project "${PROJECT_ROOT}/PhoneAVBridgeIOSApp.xcodeproj" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -sdk iphonesimulator \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY= \
  build

APP_PATH="${DERIVED_DATA_PATH}/Build/Products/${CONFIGURATION}-iphonesimulator/${APP_PRODUCT_NAME}"
if [[ ! -d "${APP_PATH}" ]]; then
  echo "Failed to locate built iOS simulator app bundle: ${APP_PRODUCT_NAME}" >&2
  exit 1
fi

mkdir -p "${DIST_DIR}"
ZIP_NAME="${APP_PRODUCT_NAME%.app}-ios-${VERSION_SUFFIX}-unsigned.zip"
ZIP_PATH="${DIST_DIR}/${ZIP_NAME}"
rm -f "${ZIP_PATH}"

ditto -c -k --sequesterRsrc --keepParent "${APP_PATH}" "${ZIP_PATH}"

echo "Unsigned iOS simulator artifact created: ${ZIP_PATH}"
echo "artifact_path=${ZIP_PATH}"
