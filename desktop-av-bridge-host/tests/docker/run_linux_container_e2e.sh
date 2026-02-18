#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.linux-e2e.yml"
HOST_API_BASE="${HOST_API_BASE:-http://127.0.0.1:18787}"

compose() {
  docker compose -f "${COMPOSE_FILE}" "$@"
}

cleanup() {
  compose down --volumes --remove-orphans >/dev/null 2>&1 || true
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

wait_for_http() {
  local url="$1"
  local attempts="${2:-60}"
  local delay="${3:-1}"
  local i
  for ((i=1; i<=attempts; i++)); do
    if curl -fsS "${url}" >/dev/null 2>&1; then
      echo "Endpoint ready: ${url} (${i}/${attempts})"
      return 0
    fi
    sleep "${delay}"
  done
  echo "Timed out waiting for endpoint: ${url}" >&2
  return 1
}

wait_for_rtsp() {
  local attempts=40
  local i
  for ((i=1; i<=attempts; i++)); do
    if compose exec -T host-agent ffprobe -v error -rtsp_transport tcp -show_streams rtsp://rtsp-server:8554/live >/dev/null 2>&1; then
      echo "RTSP stream ready (${i}/${attempts})"
      return 0
    fi
    sleep 1
  done
  echo "Timed out waiting for RTSP stream." >&2
  return 1
}

trap cleanup EXIT

require_cmd docker
require_cmd curl
require_cmd jq
require_cmd python3

echo "[linux-e2e] Building Docker services..."
compose build host-agent rtsp-publisher >/dev/null

echo "[linux-e2e] Starting services..."
compose up -d rtsp-server rtsp-publisher host-agent >/dev/null

wait_for_http "${HOST_API_BASE}/health"
wait_for_rtsp

echo "[linux-e2e] Fetching bootstrap..."
PAIR_CODE="$(curl -fsS "${HOST_API_BASE}/api/bootstrap" | jq -r '.bootstrap.pairingCode')"
if [[ -z "${PAIR_CODE}" || "${PAIR_CODE}" == "null" ]]; then
  echo "Pairing code unavailable." >&2
  exit 1
fi

echo "[linux-e2e] Pairing host..."
curl -fsS -X POST "${HOST_API_BASE}/api/pair" \
  -H 'Content-Type: application/json' \
  -d "{\"pairCode\":\"${PAIR_CODE}\",\"deviceName\":\"DockerPhone\",\"deviceId\":\"docker-phone-01\"}" >/dev/null

echo "[linux-e2e] Enabling camera + microphone + speaker..."
curl -fsS -X POST "${HOST_API_BASE}/api/toggles" \
  -H 'Content-Type: application/json' \
  -d '{"camera":true,"microphone":true,"speaker":true,"cameraStreamUrl":"rtsp://rtsp-server:8554/live","deviceName":"DockerPhone","deviceId":"docker-phone-01"}' >/dev/null

sleep 2

STATUS_JSON="$(curl -fsS "${HOST_API_BASE}/api/status")"
echo "[linux-e2e] Host status:"
echo "${STATUS_JSON}" | jq '.status.hostStatus,.status.resources,.status.issues'

echo "${STATUS_JSON}" | jq -e '.status.hostStatus == "Resource Active"' >/dev/null
echo "${STATUS_JSON}" | jq -e '.status.resources.camera == true and .status.resources.microphone == true and .status.resources.speaker == true' >/dev/null
echo "${STATUS_JSON}" | jq -e '.status.issues | length == 0' >/dev/null

echo "[linux-e2e] Verifying camera bridge process..."
compose exec -T host-agent pgrep -f 'run-bridge.sh' >/dev/null

echo "[linux-e2e] Verifying virtual microphone source creation..."
compose exec -T host-agent sh -lc "PULSE_SERVER=unix:/tmp/xdg-runtime/pulse/native pactl list short sources | grep -Eq 'phone_av_bridge_mic_src_|phone_av_bridge_mic_sink_.*\\.monitor'"

echo "[linux-e2e] Capturing speaker stream sample..."
SPEAKER_CAPTURE_FILE="$(mktemp /tmp/prc_speaker_stream_XXXXXX)"
set +e
curl -fsS --max-time 3 "${HOST_API_BASE}/api/speaker/stream" -o "${SPEAKER_CAPTURE_FILE}"
CURL_EXIT="$?"
set -e
if [[ "${CURL_EXIT}" -ne 0 && "${CURL_EXIT}" -ne 28 ]]; then
  echo "Speaker stream request failed (curl exit ${CURL_EXIT})." >&2
  exit 1
fi

python3 - <<'PY' "${SPEAKER_CAPTURE_FILE}"
import math
import struct
import sys

path = sys.argv[1]
data = open(path, "rb").read()
if len(data) < 4096:
    raise SystemExit("Speaker stream payload too small.")
n = len(data) // 2
samples = struct.unpack("<%dh" % n, data[:n * 2])
rms = math.sqrt(sum(s * s for s in samples) / max(1, len(samples)))
print({"bytes": len(data), "rms": round(rms, 2)})
if rms <= 0.5:
    raise SystemExit("Speaker stream appears silent.")
PY

echo "[linux-e2e] Linux container E2E checks passed."
