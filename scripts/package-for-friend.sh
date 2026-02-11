#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="HoldSpeak"

DIST_DIR="${ROOT_DIR}/dist"
PAYLOAD_DIR="${DIST_DIR}/${APP_NAME}"
ZIP_PATH="${DIST_DIR}/${APP_NAME}-friend.zip"

echo "Building app…"
"${ROOT_DIR}/scripts/build-macos-app.sh"

SRC_APP="${ROOT_DIR}/build/${APP_NAME}.app"
if [[ ! -d "${SRC_APP}" ]]; then
  echo "Missing app bundle: ${SRC_APP}" >&2
  exit 1
fi

rm -rf "${DIST_DIR}"
mkdir -p "${PAYLOAD_DIR}"

echo "Staging payload…"
cp -R "${SRC_APP}" "${PAYLOAD_DIR}/${APP_NAME}.app"
cp "${ROOT_DIR}/docs/FRIEND-INSTALL.md" "${PAYLOAD_DIR}/INSTALL.md"

# Avoid shipping quarantine bits from the build machine (download will still be quarantined by the recipient).
/usr/bin/xattr -dr com.apple.quarantine "${PAYLOAD_DIR}/${APP_NAME}.app" 2>/dev/null || true

echo "Creating zip: ${ZIP_PATH}"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent --norsrc "${PAYLOAD_DIR}" "${ZIP_PATH}"

echo "Done."
echo "Share: ${ZIP_PATH}"
