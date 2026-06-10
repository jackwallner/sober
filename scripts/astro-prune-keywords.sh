#!/bin/bash
# Remove Tier-D / junk keywords from Astro using MCP remove_keywords.
set -euo pipefail
cd "$(dirname "$0")/.."
export PYTHONPATH="$(dirname "$0"):${PYTHONPATH:-}"

APP_ID="${ASTRO_APP_ID:-103}"
STORE="${ASTRO_STORE:-us}"
MCP="${ASTRO_MCP_URL:-http://127.0.0.1:8089/mcp}"

python3 <<PY
import json
from pathlib import Path
from astro_mcp import remove_keywords

mcp = "$MCP"
app_id = "$APP_ID"
store = "$STORE"

strategy = json.loads(Path("scripts/astro-keyword-strategy.json").read_text())
keep = set(strategy["keywords"])
# Tier D + probe noise not in curated list
extra_remove = [
    "tracker alcohol",
    "sober tracker - alcohol free",
    "daily tracker",
    "check in tracker",
    "recovery tracker",
    "reframe drink less",
    "habit quit drinking",
    "na meeting",
    "wine free",
    "12 step tracker",
    "quit habit",
    "stop drinking app",
    "sober sidekick",
    "sober clock",
    "addiction tracker",
]
to_remove = []
for item in strategy["tiers"].get("D_remove_via_MCP", strategy["tiers"].get("D_deprioritize", [])):
    kw = item["keyword"] if isinstance(item, dict) else item
    to_remove.append(kw)
to_remove.extend(extra_remove)
to_remove = sorted(set(to_remove))

print(f"Removing {len(to_remove)} keywords from app {app_id} ({store})...")
result = remove_keywords(mcp, app_id, store, to_remove)
for batch in result["batches"]:
    if isinstance(batch, dict):
        print(f"  removed={batch.get('removed')} notFound={batch.get('notFound')}")
print("Done.")
PY
