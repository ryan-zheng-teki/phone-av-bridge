#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${HOME}/Applications/PhoneAVBridgeHost"
APP_BUNDLE="${HOME}/Applications/Phone AV Bridge Host.app"
LOG_DIR="${HOME}/Library/Logs/PhoneAVBridgeHost"
PID_FILE="${LOG_DIR}/phone-av-bridge-host.pid"

if [[ -f "${PID_FILE}" ]]; then
  PID="$(cat "${PID_FILE}")"
  if kill -0 "${PID}" >/dev/null 2>&1; then
    kill "${PID}" >/dev/null 2>&1 || true
  fi
  rm -f "${PID_FILE}"
fi

rm -rf "${TARGET_DIR}"
rm -rf "${APP_BUNDLE}"
rm -rf "${LOG_DIR}"

echo "Phone AV Bridge Host removed from ${TARGET_DIR}."
