#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SCHEME="${SCHEME:-samplecamera}"
CONFIGURATION="${CONFIGURATION:-Release}"
APP_PRODUCT_NAME="${APP_PRODUCT_NAME:-PhoneAVBridgeCamera.app}"
VERSION_SUFFIX="${VERSION_SUFFIX:-local}"
DIST_DIR="${PROJECT_ROOT}/dist"

cd "${PROJECT_ROOT}"

echo "Building unsigned ${SCHEME} (${CONFIGURATION})..."
xcodebuild \
  -project samplecamera.xcodeproj \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY= \
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
  echo "Failed to locate built app bundle: ${APP_PRODUCT_NAME}" >&2
  exit 1
fi

mkdir -p "${DIST_DIR}"
ZIP_NAME="${APP_PRODUCT_NAME%.app}-macos-${VERSION_SUFFIX}-unsigned.zip"
ZIP_PATH="${DIST_DIR}/${ZIP_NAME}"
rm -f "${ZIP_PATH}"

ditto -c -k --sequesterRsrc --keepParent "${APP_PATH}" "${ZIP_PATH}"

echo "Unsigned macOS artifact created: ${ZIP_PATH}"
echo "artifact_path=${ZIP_PATH}"
