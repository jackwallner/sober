#!/bin/bash
# Refresh scripts/astro-keyword-metrics.json from Astro MCP.
set -euo pipefail
cd "$(dirname "$0")/.."
# Default to the live App Store ID from .astro-app.json (falls back to 6768869215).
APP_ID="${ASTRO_APP_ID:-$(python3 -c "import json;print(json.load(open('scripts/.astro-app.json'))['appId'])" 2>/dev/null || echo 6768869215)}"
STORE="${ASTRO_STORE:-us}"
MCP="${ASTRO_MCP_URL:-http://127.0.0.1:8089/mcp}"
OUT="scripts/astro-keyword-metrics.json"

curl -sf -m 300 -X POST "$MCP" -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"get_app_keywords\",\"arguments\":{\"appId\":\"$APP_ID\",\"store\":\"$STORE\"}}}" \
  -o /tmp/astro-kws-raw.json

python3 - "$OUT" <<'PY'
import json, sys
d = json.load(open("/tmp/astro-kws-raw.json"))
text = d["result"]["content"][0]["text"]
data = json.loads(text)
if not isinstance(data, list):
    raise SystemExit(f"expected keyword list, got: {text[:200]}")
path = sys.argv[1]
open(path, "w").write(json.dumps(data, indent=2) + "\n")
print(f"Wrote {len(data)} keywords → {path}")
PY
