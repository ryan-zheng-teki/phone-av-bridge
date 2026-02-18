#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${HOME}/Applications/HostResourceAgent"
APP_BUNDLE="${HOME}/Applications/Host Resource Agent.app"
LOG_DIR="${HOME}/Library/Logs/HostResourceAgent"
PID_FILE="${LOG_DIR}/host-resource-agent.pid"

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

echo "Host Resource Agent removed from ${TARGET_DIR}."
