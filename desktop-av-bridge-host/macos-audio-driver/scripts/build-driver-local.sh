#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUT_DIR="${ROOT_DIR}/PhoneAVBridgeAudio.driver"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

REPO_URL="${REPO_URL:-https://github.com/ExistentialAudio/BlackHole.git}"
REPO_REF="${REPO_REF:-master}"

echo "Cloning ${REPO_URL} (${REPO_REF})..."
git clone --depth 1 --branch "${REPO_REF}" "${REPO_URL}" "${WORK_DIR}/blackhole"

cat > "${WORK_DIR}/blackhole/pab_audio.xcconfig" <<'EOF'
GCC_PREPROCESSOR_DEFINITIONS = $(inherited) kNumber_Of_Channels=2 kPlugIn_BundleID=\"org.autobyteus.phoneavbridge.audio.driver\" kDriver_Name=\"PhoneAVBridgeAudio\"
PRODUCT_BUNDLE_IDENTIFIER = org.autobyteus.phoneavbridge.audio.driver
CODE_SIGNING_ALLOWED = NO
CODE_SIGNING_REQUIRED = NO
CODE_SIGN_IDENTITY =
DEVELOPMENT_TEAM =
EOF

echo "Building PhoneAVBridgeAudio.driver..."
(
  cd "${WORK_DIR}/blackhole"
  xcodebuild -project BlackHole.xcodeproj -target BlackHole -configuration Release -xcconfig pab_audio.xcconfig clean >/dev/null
  xcodebuild -project BlackHole.xcodeproj -target BlackHole -configuration Release CONFIGURATION_BUILD_DIR=build -xcconfig pab_audio.xcconfig >/dev/null
)

mkdir -p "${OUT_DIR}"
rsync -a --delete "${WORK_DIR}/blackhole/build/BlackHole.driver/" "${OUT_DIR}/"

plutil -replace CFBundleName -string "Phone AV Bridge Audio" "${OUT_DIR}/Contents/Info.plist"
plutil -replace CFBundleDisplayName -string "Phone AV Bridge Audio" "${OUT_DIR}/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string org.autobyteus.phoneavbridge.audio.driver "${OUT_DIR}/Contents/Info.plist"
plutil -replace CFBundleExecutable -string PhoneAVBridgeAudio "${OUT_DIR}/Contents/Info.plist"

if [[ -f "${OUT_DIR}/Contents/MacOS/BlackHole" ]]; then
  mv "${OUT_DIR}/Contents/MacOS/BlackHole" "${OUT_DIR}/Contents/MacOS/PhoneAVBridgeAudio"
fi
chmod 755 "${OUT_DIR}/Contents/MacOS/PhoneAVBridgeAudio"

echo "PhoneAVBridgeAudio.driver generated at ${OUT_DIR}"
