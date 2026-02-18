#!/usr/bin/env bash
set -euo pipefail

SIZE="${SIZE:-1280x720}"
FPS="${FPS:-30}"
MODE="${MODE:-file}"
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8554}"
PATH_SUFFIX="${PATH_SUFFIX:-/live}"
DURATION_SECONDS="${DURATION_SECONDS:-0}"
OUTPUT_FILE="${OUTPUT_FILE:-/tmp/phone-ip-webcam-sim.mp4}"

usage() {
  cat <<'EOF'
Usage:
  run-simulated-source.sh [--mode file|rtsp] [--size 1280x720] [--fps 30] [--host 0.0.0.0] [--port 8554] [--path /live] [--duration 0] [--output /tmp/sim.mp4]

Description:
  Creates a synthetic source using ffmpeg testsrc.
  mode=file writes a local sample clip (default, safest).
  mode=rtsp attempts to publish RTSP from ffmpeg (requires ffmpeg build/environment support).
  Duration 0 means run until interrupted for mode=rtsp.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    --size) SIZE="$2"; shift 2 ;;
    --fps) FPS="$2"; shift 2 ;;
    --host) HOST="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --path) PATH_SUFFIX="$2"; shift 2 ;;
    --duration) DURATION_SECONDS="$2"; shift 2 ;;
    --output) OUTPUT_FILE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg is required but not found in PATH." >&2
  exit 1
fi

if [[ "${PATH_SUFFIX}" != /* ]]; then
  PATH_SUFFIX="/${PATH_SUFFIX}"
fi

URL="rtsp://${HOST}:${PORT}${PATH_SUFFIX}"

FFMPEG_ARGS=(
  -hide_banner
  -loglevel warning
  -re
  -f lavfi
  -i "testsrc=size=${SIZE}:rate=${FPS}"
  -pix_fmt yuv420p
  -c:v libx264
  -preset veryfast
  -tune zerolatency
)

if [[ "${DURATION_SECONDS}" != "0" ]]; then
  FFMPEG_ARGS+=(-t "${DURATION_SECONDS}")
fi

if [[ "${MODE}" == "file" ]]; then
  if [[ "${DURATION_SECONDS}" == "0" ]]; then
    DURATION_SECONDS=5
    FFMPEG_ARGS+=(-t "${DURATION_SECONDS}")
  fi
  FFMPEG_ARGS+=(
    -movflags +faststart
    -y
    "${OUTPUT_FILE}"
  )
  echo "Generating simulated file source at ${OUTPUT_FILE}"
  echo "size=${SIZE} fps=${FPS} duration=${DURATION_SECONDS}s"
  ffmpeg "${FFMPEG_ARGS[@]}"
  exit $?
fi

if [[ "${MODE}" == "rtsp" ]]; then
  FFMPEG_ARGS+=(
    -f rtsp
    -rtsp_transport tcp
    -rtsp_flags listen
    "${URL}"
  )
  echo "Starting simulated RTSP source at ${URL}"
  echo "size=${SIZE} fps=${FPS} duration=${DURATION_SECONDS}s"
  set +e
  ffmpeg "${FFMPEG_ARGS[@]}"
  status=$?
  set -e
  if [[ "${status}" -ne 0 ]]; then
    echo "RTSP publish failed with exit code ${status}." >&2
    echo "Hint: this ffmpeg build/environment may not support RTSP server publish mode." >&2
    echo "Hint: use --mode file for local simulation, or provide an external RTSP server (for example mediamtx)." >&2
  fi
  exit "${status}"
fi

echo "Unsupported mode: ${MODE}. Use file or rtsp." >&2
exit 2
