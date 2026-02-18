#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_FILE="${PROJECT_DIR}/docker-compose.emulation.yml"

cleanup() {
  docker compose -f "${COMPOSE_FILE}" down --volumes --remove-orphans >/dev/null 2>&1 || true
}

trap cleanup EXIT

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

compose() {
  docker compose -f "${COMPOSE_FILE}" "$@"
}

wait_for_rtsp() {
  local attempts=30
  local delay_seconds=1
  local i
  for ((i=1; i<=attempts; i++)); do
    if compose exec -T bridge-test ffprobe -v error -rtsp_transport tcp -show_streams rtsp://rtsp-server:8554/live >/dev/null 2>&1; then
      echo "RTSP stream is ready (attempt ${i}/${attempts})"
      return 0
    fi
    sleep "${delay_seconds}"
  done
  echo "Timed out waiting for RTSP stream readiness." >&2
  return 1
}

main() {
  require_cmd docker

  echo "[emulation] Building bridge-test image..."
  compose build bridge-test >/dev/null

  echo "[emulation] Starting RTSP server, publisher, and bridge-test services..."
  compose up -d rtsp-server rtsp-publisher bridge-test >/dev/null

  echo "[emulation] Waiting for RTSP stream..."
  wait_for_rtsp

  echo "[emulation] Running preflight in container..."
  compose exec -T bridge-test ./bin/preflight.sh

  echo "[emulation] Running bridge ingest emulation (linux-null-emulator)..."
  compose exec -T bridge-test env \
    STREAM_SOURCE_URL=rtsp://rtsp-server:8554/live \
    SINK_BACKEND=linux-null-emulator \
    FRAME_SIZE=640x360 \
    FRAME_RATE=15 \
    MAX_SECONDS=5 \
    ./bin/run-bridge.sh

  echo "[emulation] Running bridge file-output emulation (linux-file-emulator)..."
  compose exec -T bridge-test env \
    STREAM_SOURCE_URL=rtsp://rtsp-server:8554/live \
    SINK_BACKEND=linux-file-emulator \
    OUTPUT_FILE=/tmp/bridge-output.mp4 \
    FRAME_SIZE=640x360 \
    FRAME_RATE=15 \
    MAX_SECONDS=5 \
    ./bin/run-bridge.sh

  echo "[emulation] Verifying file-output artifact..."
  compose exec -T bridge-test ffprobe -v error -show_streams /tmp/bridge-output.mp4 >/dev/null
  compose exec -T bridge-test test -s /tmp/bridge-output.mp4

  echo "[emulation] Running bridge dry-run for linux-v4l2 command generation..."
  compose exec -T bridge-test env \
    STREAM_SOURCE_URL=rtsp://rtsp-server:8554/live \
    SINK_BACKEND=linux-v4l2 \
    V4L2_DEVICE=/dev/video2 \
    MAX_SECONDS=5 \
    ./bin/run-bridge.sh --dry-run

  echo "[emulation] All Docker emulation checks passed."
}

main "$@"
