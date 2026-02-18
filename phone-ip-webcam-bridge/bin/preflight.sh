#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

FAIL_COUNT=0
WARN_COUNT=0

OS_NAME="$(uname -s)"

print_header() {
  echo "phone-ip-webcam-bridge preflight"
  echo "project: ${PROJECT_DIR}"
  echo "os: ${OS_NAME}"
  echo
}

pass() {
  printf "PASS  %s\n" "$1"
}

warn() {
  WARN_COUNT=$((WARN_COUNT + 1))
  printf "WARN  %s\n" "$1"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "FAIL  %s\n" "$1"
}

check_command() {
  local cmd="$1"
  local required="${2:-required}"
  if command -v "${cmd}" >/dev/null 2>&1; then
    pass "command '${cmd}' available"
  else
    if [[ "${required}" == "required" ]]; then
      fail "command '${cmd}' missing"
    else
      warn "optional command '${cmd}' missing"
    fi
  fi
}

check_linux_capabilities() {
  if [[ "${OS_NAME}" != "Linux" ]]; then
    warn "linux capability checks skipped on non-Linux host"
    return 0
  fi

  if ls /dev/video* >/dev/null 2>&1; then
    pass "video devices detected under /dev"
  else
    warn "no /dev/video* device found"
  fi

  if command -v lsmod >/dev/null 2>&1 && lsmod | grep -q '^v4l2loopback'; then
    pass "v4l2loopback module appears loaded"
  else
    warn "v4l2loopback module not detected (required for virtual webcam sink)"
  fi
}

check_macos_capabilities() {
  if [[ "${OS_NAME}" != "Darwin" ]]; then
    warn "macOS capability checks skipped on non-macOS host"
    return 0
  fi

  if xcode-select -p >/dev/null 2>&1; then
    pass "xcode command line tools available"
  else
    warn "xcode command line tools missing (needed for camera extension development)"
  fi

  if [[ -d /Library/CoreMediaIO/Plug-Ins/DAL ]]; then
    pass "CoreMediaIO plugin directory present"
  else
    warn "CoreMediaIO plugin directory not found"
  fi
}

check_android_tooling() {
  check_command "adb" "optional"
  if command -v adb >/dev/null 2>&1; then
    if adb devices | awk 'NR>1 && $2=="device" {found=1} END {exit found?0:1}'; then
      pass "at least one authorized Android device detected"
    else
      warn "no authorized Android device currently attached"
    fi
  fi
}

print_summary() {
  echo
  echo "summary:"
  echo "  failures: ${FAIL_COUNT}"
  echo "  warnings: ${WARN_COUNT}"

  if [[ "${FAIL_COUNT}" -gt 0 ]]; then
    echo "result: NOT READY"
    return 1
  fi

  echo "result: READY WITH WARNINGS/NOTES"
  return 0
}

main() {
  print_header

  check_command "ffmpeg" "required"
  check_command "ffprobe" "optional"

  check_linux_capabilities
  check_macos_capabilities
  check_android_tooling

  print_summary
}

main "$@"
