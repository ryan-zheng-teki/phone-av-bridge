#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PRE_FLIGHT="${PROJECT_DIR}/bin/preflight.sh"

if [[ ! -x "${PRE_FLIGHT}" ]]; then
  echo "preflight script is not executable: ${PRE_FLIGHT}" >&2
  exit 1
fi

OUTPUT_FILE="$(mktemp)"
trap 'rm -f "${OUTPUT_FILE}"' EXIT

set +e
"${PRE_FLIGHT}" >"${OUTPUT_FILE}" 2>&1
STATUS=$?
set -e

if ! grep -q "phone-av-camera-bridge-runtime preflight" "${OUTPUT_FILE}"; then
  echo "missing preflight header" >&2
  cat "${OUTPUT_FILE}" >&2
  exit 1
fi

if ! grep -q "command 'ffmpeg' available" "${OUTPUT_FILE}"; then
  echo "missing ffmpeg check line" >&2
  cat "${OUTPUT_FILE}" >&2
  exit 1
fi

# Expected behavior: exit can be 0 or 1 depending on host readiness;
# smoke test validates deterministic output shape, not full machine readiness.
if [[ "${STATUS}" -ne 0 && "${STATUS}" -ne 1 ]]; then
  echo "unexpected preflight exit code: ${STATUS}" >&2
  cat "${OUTPUT_FILE}" >&2
  exit 1
fi

echo "preflight smoke test passed (exit=${STATUS})"
