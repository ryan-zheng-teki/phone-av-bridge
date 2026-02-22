#!/usr/bin/env bash
set -euo pipefail

# Push current repo's main branch to origin using GitHub HTTPS + PAT.
# Credentials are loaded from .secrets/github-pat.env (preferred) or env vars.
# Default username is set for this project owner, but can be overridden.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SECRETS_FILE="${REPO_ROOT}/.secrets/github-pat.env"
GITHUB_USERNAME="${GITHUB_USERNAME:-ryan-zheng-teki}"

if [[ -f "${SECRETS_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${SECRETS_FILE}"
fi

if [[ -z "${GITHUB_PAT:-}" ]]; then
  cat >&2 <<MSG
error: missing GitHub PAT.

Create ${SECRETS_FILE} with:
  GITHUB_USERNAME=ryan-zheng-teki
  GITHUB_PAT=ghp_xxx

Then run:
  ./scripts/push-origin-main.sh
MSG
  exit 1
fi

if [[ -f "${SECRETS_FILE}" ]]; then
  chmod 600 "${SECRETS_FILE}" || true
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "error: run inside a git repository" >&2
  exit 1
fi

REMOTE_URL="$(git remote get-url origin)"
if [[ "${REMOTE_URL}" != https://github.com/* ]]; then
  echo "error: origin is not an HTTPS GitHub remote: ${REMOTE_URL}" >&2
  exit 1
fi

# Ensure approved credentials are persisted for non-interactive pushes.
if ! git config --get-all credential.helper >/dev/null 2>&1; then
  git config --global credential.helper store
fi

# Store credentials for this host so git push can use them non-interactively.
# User can clear later with: git credential reject ...
printf 'protocol=https\nhost=github.com\nusername=%s\npassword=%s\n\n' "${GITHUB_USERNAME}" "${GITHUB_PAT}" | git credential approve

# Push main branch to origin.
GIT_TERMINAL_PROMPT=0 git push origin main

echo "push complete: origin/main"
