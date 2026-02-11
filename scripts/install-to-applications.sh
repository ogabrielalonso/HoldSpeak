#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="HoldSpeak"
SRC_APP="${ROOT_DIR}/build/${APP_NAME}.app"
DST_APP="/Applications/${APP_NAME}.app"

if [[ ! -d "${SRC_APP}" ]]; then
  echo "Missing app bundle: ${SRC_APP}" >&2
  echo "Build it first: ${ROOT_DIR}/scripts/build-macos-app.sh" >&2
  exit 1
fi

echo "Installing to: ${DST_APP}"

if [[ -t 0 ]]; then
  sudo rm -rf "${DST_APP}"
  sudo cp -R "${SRC_APP}" "${DST_APP}"
  sudo xattr -dr com.apple.quarantine "${DST_APP}" 2>/dev/null || true
else
  # Non-interactive environments (like Codex) can't prompt for sudo in-terminal.
  # Use a GUI admin prompt instead.
  /usr/bin/osascript <<OSA
do shell script "rm -rf '$DST_APP' && cp -R '$SRC_APP' '$DST_APP' && xattr -dr com.apple.quarantine '$DST_APP' || true" with administrator privileges
OSA
fi

echo "Done."
echo "Open: open \"${DST_APP}\""
