#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${HOME}/.local/share/host-resource-agent"
BIN_DIR="${HOME}/.local/bin"
APP_DIR="${HOME}/.local/share/applications"
LOG_DIR="${HOME}/.local/state/host-resource-agent"

rm -rf "${TARGET_DIR}"
rm -f "${BIN_DIR}/host-resource-agent-start"
rm -f "${BIN_DIR}/host-resource-agent-stop"
rm -f "${APP_DIR}/host-resource-agent.desktop"
rm -rf "${LOG_DIR}"

echo "Host Resource Agent uninstalled."
