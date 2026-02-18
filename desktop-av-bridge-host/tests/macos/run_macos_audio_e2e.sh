#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOST_DIR="${ROOT_DIR}"
RTSP_URL="${RTSP_URL:-rtsp://127.0.0.1:8554/live}"
OUTPUT_DEVICE="${MACOS_AUDIO_OUTPUT_DEVICE:-PhoneAVBridgeAudio 2ch}"
HOST_PORT="${HOST_PORT:-18787}"
HOST_BASE="http://127.0.0.1:${HOST_PORT}"

cleanup() {
  set +e
  if [[ -n "${HOST_PID:-}" ]]; then
    kill "${HOST_PID}" >/dev/null 2>&1 || true
  fi
  if [[ -n "${PUB_PID:-}" ]]; then
    kill "${PUB_PID}" >/dev/null 2>&1 || true
  fi
  docker rm -f pavb-mediamtx >/dev/null 2>&1 || true
}
trap cleanup EXIT

cd "${HOST_DIR}"

pkill -f "node desktop-app/server.mjs" >/dev/null 2>&1 || true
docker rm -f pavb-mediamtx >/dev/null 2>&1 || true
docker run -d --name pavb-mediamtx -p 8554:8554 bluenviron/mediamtx:latest >/dev/null
sleep 1

ffmpeg -hide_banner -loglevel warning -re \
  -f lavfi -i sine=frequency=1000:sample_rate=48000 \
  -c:a aac -b:a 128k \
  -f rtsp -rtsp_transport tcp "${RTSP_URL}" >/tmp/pavb_rtsp_publish.log 2>&1 &
PUB_PID=$!

for _ in {1..20}; do
  if ffprobe -v error -rtsp_transport tcp -show_streams "${RTSP_URL}" >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
done
ffprobe -v error -rtsp_transport tcp -show_streams "${RTSP_URL}" >/dev/null

ENABLE_DISCOVERY=0 \
PERSIST_STATE=0 \
PORT="${HOST_PORT}" \
HOST=127.0.0.1 \
ADVERTISED_HOST=127.0.0.1 \
MACOS_AUDIO_OUTPUT_DEVICE="${OUTPUT_DEVICE}" \
node desktop-app/server.mjs >/tmp/pavb_host.log 2>&1 &
HOST_PID=$!
sleep 2

bootstrap=$(curl -fsS "${HOST_BASE}/api/bootstrap")
pair_code=$(echo "${bootstrap}" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));process.stdout.write(d.bootstrap.pairingCode)")

curl -fsS -X POST "${HOST_BASE}/api/pair" \
  -H 'content-type: application/json' \
  -d "{\"pairCode\":\"${pair_code}\",\"deviceName\":\"Pixel Test\",\"deviceId\":\"pixel-test-01\"}" >/dev/null

curl -fsS -X POST "${HOST_BASE}/api/toggles" \
  -H 'content-type: application/json' \
  -d "{\"camera\":false,\"microphone\":true,\"speaker\":true,\"cameraStreamUrl\":\"${RTSP_URL}\",\"deviceName\":\"Pixel Test\",\"deviceId\":\"pixel-test-01\"}" >/dev/null

sleep 2
curl -fsS "${HOST_BASE}/api/status" > /tmp/pavb_status.json
mic="$(jq -r '.status.resources.microphone' /tmp/pavb_status.json)"
spk="$(jq -r '.status.resources.speaker' /tmp/pavb_status.json)"
issues="$(jq '.status.issues | length' /tmp/pavb_status.json)"

if [[ "${mic}" != "true" || "${spk}" != "true" || "${issues}" != "0" ]]; then
  echo "macos-e2e failed: status not healthy" >&2
  jq '.status' /tmp/pavb_status.json >&2
  exit 1
fi

speaker_raw="$(mktemp /tmp/pavb_speaker_raw_XXXXXX)"
set +e
curl -sS --max-time 6 "${HOST_BASE}/api/speaker/stream" -o "${speaker_raw}"
curl_exit=$?
set -e

speaker_bytes="$(wc -c < "${speaker_raw}" | tr -d ' ')"
if [[ "${speaker_bytes}" -le 0 ]]; then
  echo "macos-e2e failed: speaker stream empty (curl exit=${curl_exit})" >&2
  exit 1
fi

max_volume="$(ffmpeg -hide_banner -f s16le -ar 48000 -ac 1 -i "${speaker_raw}" -af volumedetect -f null - 2>&1 | rg 'max_volume' | head -n1 || true)"
if [[ -z "${max_volume}" ]]; then
  echo "macos-e2e failed: volume analysis missing" >&2
  exit 1
fi

echo "macos-e2e pass"
echo "speaker_stream_bytes=${speaker_bytes}"
echo "curl_exit=${curl_exit}"
echo "${max_volume}"
