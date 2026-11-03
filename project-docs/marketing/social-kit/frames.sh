#!/bin/sh
# Render the app's real BonsaiView for every style and day 0-365 (transparent 1200 px PNGs) into frames/.
set -e
cd "$(dirname "$0")"
OUT="$PWD/frames"
mkdir -p "$OUT"
cd ../../../Tools/BonsaiAudit
swift build -c release
./.build/release/BonsaiAudit --mode=render --config=design600 --alpha --out="$OUT" \
  --days="$(python3 -c "print(','.join(map(str, range(366))))")" > /dev/null
