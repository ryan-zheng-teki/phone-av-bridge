#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${HOME}/.local/share/phone-av-bridge-host"
BIN_DIR="${HOME}/.local/bin"
APP_DIR="${HOME}/.local/share/applications"
LOG_DIR="${HOME}/.local/state/phone-av-bridge-host"

rm -rf "${TARGET_DIR}"
rm -f "${BIN_DIR}/phone-av-bridge-host-start"
rm -f "${BIN_DIR}/phone-av-bridge-host-stop"
rm -f "${APP_DIR}/phone-av-bridge-host.desktop"
rm -rf "${LOG_DIR}"

echo "Phone AV Bridge Host uninstalled."
