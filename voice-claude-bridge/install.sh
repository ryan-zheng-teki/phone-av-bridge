#!/usr/bin/env bash
set -euo pipefail

# Installation script for voice-claude-bridge
# This script symlinks the voice-claude wrapper to a directory in your PATH.

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
BIN_NAME="voice-claude"
SRC_BIN="${SCRIPT_DIR}/${BIN_NAME}"
DEFAULT_INSTALL_DIR="${HOME}/.local/bin"

usage() {
  echo "Usage: $0 [install_dir]"
  echo "Default install_dir: ${DEFAULT_INSTALL_DIR}"
}

install_bin() {
  local target_dir="${1:-${DEFAULT_INSTALL_DIR}}"

  if [[ ! -d "${target_dir}" ]]; then
    echo "Error: Directory ${target_dir} does not exist."
    exit 1
  fi

  local target_bin="${target_dir}/${BIN_NAME}"

  if [[ -L "${target_bin}" ]]; then
    echo "Removing existing symlink at ${target_bin}"
    rm "${target_bin}"
  elif [[ -f "${target_bin}" ]]; then
    echo "Error: A file already exists at ${target_bin} and it is not a symlink."
    exit 1
  fi

  echo "Creating symlink: ${target_bin} -> ${SRC_BIN}"
  ln -s "${SRC_BIN}" "${target_bin}"

  echo "Installation complete."
  if [[ ":$PATH:" != *":${target_dir}:"* ]]; then
    echo "Warning: ${target_dir} is not in your PATH. You may need to add it to your shell config."
  fi
}

check_prereqs() {
  local system_name
  system_name="$(uname -s)"

  if [[ "${system_name}" == "Linux" ]]; then
    if ! command -v parec >/dev/null 2>&1; then
      echo "Warning: 'parec' not found. Please install pulseaudio-utils (e.g., sudo apt install pulseaudio-utils)."
    fi
  elif [[ "${system_name}" == "Darwin" ]]; then
    if ! command -v ffmpeg >/dev/null 2>&1; then
      echo "Warning: 'ffmpeg' not found. Please install it via Homebrew: brew install ffmpeg"
    fi
  else
    echo "Warning: Unsupported operating system: ${system_name}. Audio capture may not work."
  fi

  # Check for Python versions
  local python_found=false
  for cmd in python3.11 python3.12 python3.13 python3.10 python3.9 python3; do
    if command -v "${cmd}" >/dev/null 2>&1; then
      python_found=true
      break
    fi
  done

  if [[ "${python_found}" == false ]]; then
    echo "Warning: No supported Python 3 version (3.9-3.13) found in PATH."
  fi
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

check_prereqs
install_bin "${1:-}"
