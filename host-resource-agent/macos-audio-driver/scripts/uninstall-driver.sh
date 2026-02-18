#!/usr/bin/env bash
set -euo pipefail

TARGET_BUNDLE="/Library/Audio/Plug-Ins/HAL/PRCAudio.driver"
ESCALATED_FLAG="${1:-}"

if [[ "${EUID}" -ne 0 && "${ESCALATED_FLAG}" != "--as-root" && ! -t 0 ]]; then
  escaped_cmd=$(printf '%q ' "$0" --as-root)
  osascript -e "do shell script \"${escaped_cmd}\" with administrator privileges"
  exit 0
fi

run_with_privilege() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

if run_with_privilege test -d "${TARGET_BUNDLE}"; then
  run_with_privilege rm -rf "${TARGET_BUNDLE}"
  echo "Removed ${TARGET_BUNDLE}"
else
  echo "No installed PRCAudio.driver at ${TARGET_BUNDLE}"
fi

echo "Restarting coreaudiod..."
if [[ "${EUID}" -eq 0 ]]; then
  killall -9 coreaudiod || true
else
  sudo killall -9 coreaudiod || true
fi

echo "Done."
