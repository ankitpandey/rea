#!/bin/bash
# Prepare REA for Claude Code cloud sessions: the toolchain pinned in .nvmrc,
# the locked dependencies, and the compiled runtime that .mcp.json starts.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}"

# The image's default Node may differ from .nvmrc. nvm's bundled npm for the
# pinned Node matches package.json#packageManager. nvm.sh does not support
# `set -eu`, so relax it while nvm runs.
export NVM_DIR="${NVM_DIR:-/opt/nvm}"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  set +eu
  . "$NVM_DIR/nvm.sh"
  nvm install --no-progress >/dev/null && nvm use >/dev/null
  nvm_status=$?
  set -eu
  if [ "$nvm_status" -ne 0 ]; then
    echo "nvm could not install the Node.js version in .nvmrc" >&2
    exit "$nvm_status"
  fi
  if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    echo "export PATH=\"$(dirname "$(command -v node)"):\$PATH\"" >>"$CLAUDE_ENV_FILE"
  fi
fi
echo "Using Node.js $(node --version) and npm $(npm --version)"

# npm ci replaces node_modules, so run it only when the installed direct
# dependencies no longer match package-lock.json.
if ! node scripts/check-dependency-install.mjs >/dev/null 2>&1; then
  npm ci --no-audit --no-fund
fi

# Turbo caches this build, so an unchanged checkout rebuilds in seconds.
npm run build:cached
