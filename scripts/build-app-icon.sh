#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <source.png> <output.icns>" >&2
  exit 2
fi

SRC_PNG="$1"
OUT_ICNS="$2"

if [[ ! -f "$SRC_PNG" ]]; then
  echo "Missing source png: $SRC_PNG" >&2
  exit 1
fi

if ! command -v /usr/bin/sips >/dev/null 2>&1; then
  echo "Missing sips (expected at /usr/bin/sips)" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "Missing python3" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TMP_DIR="$(/usr/bin/mktemp -d "/tmp/holdspeak-icon.XXXXXX")"
P128="${TMP_DIR}/icon_128.png"
P256="${TMP_DIR}/icon_256.png"
P512="${TMP_DIR}/icon_512.png"
P1024="${TMP_DIR}/icon_1024.png"

/usr/bin/sips -z 128 128 "$SRC_PNG" --out "$P128" >/dev/null
/usr/bin/sips -z 256 256 "$SRC_PNG" --out "$P256" >/dev/null
/usr/bin/sips -z 512 512 "$SRC_PNG" --out "$P512" >/dev/null
/usr/bin/sips -z 1024 1024 "$SRC_PNG" --out "$P1024" >/dev/null

python3 "${SCRIPT_DIR}/pack-icns.py" "$P128" "$P256" "$P512" "$P1024" "$OUT_ICNS"

rm -rf "${TMP_DIR}"

