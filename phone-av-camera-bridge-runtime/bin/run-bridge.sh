#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

CONFIG_PATH="${PROJECT_DIR}/config/bridge.local.env"
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage:
  run-bridge.sh [--config /path/to/bridge.env] [--dry-run]

Description:
  Ingests an RTSP source and dispatches to an OS-specific sink backend.
  Linux backend writes to v4l2loopback device.
  macOS backend is a deterministic stub until Camera Extension adapter is implemented.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG_PATH="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift 1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

warn() {
  echo "WARN: $*" >&2
}

info() {
  echo "INFO: $*"
}

redact_url() {
  local url="$1"
  # Redact obvious token-bearing query parameter values.
  echo "${url}" | sed -E 's/([?&](token|auth|key|apikey)=)[^&]+/\1REDACTED/g'
}

load_config() {
  if [[ -f "${CONFIG_PATH}" ]]; then
    info "Loading config from ${CONFIG_PATH}"
    # shellcheck disable=SC1090
    set -a; source "${CONFIG_PATH}"; set +a
  else
    warn "Config file not found at ${CONFIG_PATH}; relying on environment variables"
  fi

  STREAM_SOURCE_PROTOCOL="${STREAM_SOURCE_PROTOCOL:-rtsp}"
  STREAM_SOURCE_URL="${STREAM_SOURCE_URL:-}"
  STREAM_AUTH_TOKEN="${STREAM_AUTH_TOKEN:-}"
  SINK_BACKEND="${SINK_BACKEND:-}"
  V4L2_DEVICE="${V4L2_DEVICE:-/dev/video2}"
  OUTPUT_FILE="${OUTPUT_FILE:-/tmp/phone-av-camera-runtime-output.mp4}"
  FRAME_SIZE="${FRAME_SIZE:-1280x720}"
  FRAME_RATE="${FRAME_RATE:-30}"
  FFMPEG_LOGLEVEL="${FFMPEG_LOGLEVEL:-warning}"
  MAX_SECONDS="${MAX_SECONDS:-0}"
}

resolve_os() {
  OS_NAME="$(uname -s)"
  case "${OS_NAME}" in
    Linux|Darwin) ;;
    *)
      fail "Unsupported OS: ${OS_NAME}"
      ;;
  esac
}

validate_config() {
  [[ -n "${STREAM_SOURCE_URL}" ]] || fail "STREAM_SOURCE_URL is required"
  [[ "${STREAM_SOURCE_PROTOCOL}" == "rtsp" ]] || fail "MVP only supports STREAM_SOURCE_PROTOCOL=rtsp"
  [[ "${STREAM_SOURCE_URL}" == rtsp://* ]] || fail "STREAM_SOURCE_URL must start with rtsp://"
  [[ "${FRAME_SIZE}" =~ ^[0-9]+x[0-9]+$ ]] || fail "FRAME_SIZE must match WIDTHxHEIGHT"
  [[ "${FRAME_RATE}" =~ ^[0-9]+$ ]] || fail "FRAME_RATE must be an integer"
  [[ "${MAX_SECONDS}" =~ ^[0-9]+$ ]] || fail "MAX_SECONDS must be an integer >= 0"
  command -v ffmpeg >/dev/null 2>&1 || fail "ffmpeg is required but not found in PATH"

  if [[ -n "${STREAM_AUTH_TOKEN}" ]]; then
    info "STREAM_AUTH_TOKEN provided (token value is not printed)"
  fi

  if [[ -z "${SINK_BACKEND}" ]]; then
    if [[ "${OS_NAME}" == "Linux" ]]; then
      SINK_BACKEND="linux-v4l2"
    else
      SINK_BACKEND="macos-extension-adapter"
    fi
  fi
}

run_linux_backend() {
  [[ "${OS_NAME}" == "Linux" ]] || fail "linux-v4l2 backend requires Linux host"
  if [[ "${DRY_RUN}" != "1" ]]; then
    [[ -e "${V4L2_DEVICE}" ]] || fail "V4L2 device does not exist: ${V4L2_DEVICE}"
  elif [[ ! -e "${V4L2_DEVICE}" ]]; then
    warn "V4L2 device does not exist: ${V4L2_DEVICE} (continuing because --dry-run is enabled)"
  fi

  local width height sanitized_url
  width="${FRAME_SIZE%x*}"
  height="${FRAME_SIZE#*x}"
  sanitized_url="$(redact_url "${STREAM_SOURCE_URL}")"

  info "Starting Linux v4l2 bridge"
  info "source=${sanitized_url} sink=${V4L2_DEVICE} size=${FRAME_SIZE} fps=${FRAME_RATE}"

  local ffmpeg_cmd=(
    ffmpeg
    -hide_banner
    -loglevel "${FFMPEG_LOGLEVEL}"
    -rtsp_transport tcp
    -i "${STREAM_SOURCE_URL}"
    -vf "scale=${width}:${height},fps=${FRAME_RATE}"
    -pix_fmt yuv420p
    -f v4l2
    "${V4L2_DEVICE}"
  )

  if [[ "${MAX_SECONDS}" -gt 0 ]]; then
    ffmpeg_cmd=( "${ffmpeg_cmd[@]:0:4}" -t "${MAX_SECONDS}" "${ffmpeg_cmd[@]:4}" )
  fi

  if [[ "${DRY_RUN}" == "1" ]]; then
    info "Dry run enabled; command preview:"
    printf ' %q' "${ffmpeg_cmd[@]}"
    echo
    return 0
  fi

  if "${ffmpeg_cmd[@]}"; then
    info "Bridge exited normally."
    return 0
  fi

  fail "Bridge process failed; verify source URL, codec compatibility, and sink device readiness."
}

run_linux_null_emulator_backend() {
  [[ "${OS_NAME}" == "Linux" ]] || fail "linux-null-emulator backend requires Linux host"

  local width height sanitized_url
  width="${FRAME_SIZE%x*}"
  height="${FRAME_SIZE#*x}"
  sanitized_url="$(redact_url "${STREAM_SOURCE_URL}")"

  info "Starting Linux null-emulator bridge (ingest validation only)"
  info "source=${sanitized_url} size=${FRAME_SIZE} fps=${FRAME_RATE} max_seconds=${MAX_SECONDS}"

  local ffmpeg_cmd=(
    ffmpeg
    -hide_banner
    -loglevel "${FFMPEG_LOGLEVEL}"
    -rtsp_transport tcp
    -i "${STREAM_SOURCE_URL}"
    -vf "scale=${width}:${height},fps=${FRAME_RATE}"
    -pix_fmt yuv420p
    -f null
    -
  )

  if [[ "${MAX_SECONDS}" -gt 0 ]]; then
    ffmpeg_cmd=( "${ffmpeg_cmd[@]:0:4}" -t "${MAX_SECONDS}" "${ffmpeg_cmd[@]:4}" )
  fi

  if [[ "${DRY_RUN}" == "1" ]]; then
    info "Dry run enabled; command preview:"
    printf ' %q' "${ffmpeg_cmd[@]}"
    echo
    return 0
  fi

  if "${ffmpeg_cmd[@]}"; then
    info "Null-emulator run completed successfully."
    return 0
  fi

  fail "Null-emulator bridge failed; verify source stream availability and codec compatibility."
}

run_linux_file_emulator_backend() {
  [[ "${OS_NAME}" == "Linux" ]] || fail "linux-file-emulator backend requires Linux host"

  local width height sanitized_url
  width="${FRAME_SIZE%x*}"
  height="${FRAME_SIZE#*x}"
  sanitized_url="$(redact_url "${STREAM_SOURCE_URL}")"

  info "Starting Linux file-emulator bridge (ingest + output artifact)"
  info "source=${sanitized_url} output=${OUTPUT_FILE} size=${FRAME_SIZE} fps=${FRAME_RATE} max_seconds=${MAX_SECONDS}"

  local ffmpeg_cmd=(
    ffmpeg
    -hide_banner
    -loglevel "${FFMPEG_LOGLEVEL}"
    -rtsp_transport tcp
    -i "${STREAM_SOURCE_URL}"
    -vf "scale=${width}:${height},fps=${FRAME_RATE}"
    -pix_fmt yuv420p
    -an
    -c:v libx264
    -preset veryfast
    -movflags +faststart
    -y
    "${OUTPUT_FILE}"
  )

  if [[ "${MAX_SECONDS}" -gt 0 ]]; then
    ffmpeg_cmd=( "${ffmpeg_cmd[@]:0:4}" -t "${MAX_SECONDS}" "${ffmpeg_cmd[@]:4}" )
  fi

  if [[ "${DRY_RUN}" == "1" ]]; then
    info "Dry run enabled; command preview:"
    printf ' %q' "${ffmpeg_cmd[@]}"
    echo
    return 0
  fi

  if "${ffmpeg_cmd[@]}"; then
    info "File-emulator run completed successfully."
    return 0
  fi

  fail "File-emulator bridge failed; verify source stream availability and codec compatibility."
}

run_macos_adapter_stub() {
  [[ "${OS_NAME}" == "Darwin" ]] || fail "macos-extension-adapter backend requires macOS host"
  info "macOS Camera Extension adapter is not implemented in MVP."
  info "See contract: ${PROJECT_DIR}/docs/macos-camera-extension-adapter.md"
  return 3
}

main() {
  load_config
  resolve_os
  validate_config

  case "${SINK_BACKEND}" in
    linux-v4l2)
      run_linux_backend
      ;;
    linux-null-emulator)
      run_linux_null_emulator_backend
      ;;
    linux-file-emulator)
      run_linux_file_emulator_backend
      ;;
    macos-extension-adapter)
      run_macos_adapter_stub
      ;;
    *)
      fail "Unknown SINK_BACKEND: ${SINK_BACKEND}"
      ;;
  esac
}

main "$@"
