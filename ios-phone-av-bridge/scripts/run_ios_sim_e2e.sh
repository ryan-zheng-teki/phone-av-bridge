#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOST_DIR="${ROOT_DIR}/desktop-av-bridge-host"
PKG_DIR="${ROOT_DIR}/ios-phone-av-bridge"
HOST_PORT="${HOST_PORT:-8787}"
HOST_BASE_URL="${HOST_BASE_URL:-http://127.0.0.1:${HOST_PORT}}"
SIM_NAME="${IOS_SIM_NAME:-iPhone 17 Pro}"
DERIVED_DATA="${PKG_DIR}/.derivedData-ios-sim"

HOST_LOG="${PKG_DIR}/.ios-sim-host.log"
TEST_LOG="${PKG_DIR}/.ios-sim-test.log"

cleanup() {
  if [[ -n "${HOST_PID:-}" ]] && kill -0 "${HOST_PID}" >/dev/null 2>&1; then
    kill "${HOST_PID}" >/dev/null 2>&1 || true
    wait "${HOST_PID}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

wait_for_host() {
  local attempts=40
  for ((i=1; i<=attempts; i++)); do
    if curl -fsS "${HOST_BASE_URL}/health" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.25
  done
  echo "[ios-sim-e2e] host did not become healthy at ${HOST_BASE_URL}" >&2
  return 1
}

echo "[ios-sim-e2e] starting host in mock mode..."
(
  cd "${HOST_DIR}"
  HOST_BIND=127.0.0.1 \
  ADVERTISED_HOST=127.0.0.1 \
  PORT="${HOST_PORT}" \
  USE_MOCK_ADAPTERS=1 \
  ENABLE_DISCOVERY=1 \
  node desktop-app/server.mjs
) >"${HOST_LOG}" 2>&1 &
HOST_PID=$!

wait_for_host

echo "[ios-sim-e2e] running iOS simulator tests on '${SIM_NAME}'..."
(
  cd "${PKG_DIR}"
  RUN_HOST_INTEGRATION_TESTS=1 \
  HOST_BASE_URL="${HOST_BASE_URL}" \
  xcodebuild test \
    -scheme PhoneAVBridgeIOS \
    -destination "platform=iOS Simulator,name=${SIM_NAME}" \
    -derivedDataPath "${DERIVED_DATA}"
) >"${TEST_LOG}" 2>&1

echo "[ios-sim-e2e] success"
echo "[ios-sim-e2e] host log: ${HOST_LOG}"
echo "[ios-sim-e2e] test log: ${TEST_LOG}"
