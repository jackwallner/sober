#!/usr/bin/env python3
"""Upload out/<loc>/ipad/*.png (13-inch iPad, 2064x2752) to a draft version.

usage: upload_ipad.py <version-id> <locale> [<locale> ...]

Replaces the APP_IPAD_PRO_3GEN_129 set of each locale (deleting any shots in
it first), then reserves, uploads and commits each frame in filename order.
Never submits anything.
"""
import hashlib
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path.home() / "ios" / "release"))
import release as r  # noqa: E402

DISPLAY = "APP_IPAD_PRO_3GEN_129"
OUT = Path(__file__).resolve().parent.parent / "out"


def upload(c: "r.ASC", loc_id: str, files: list[Path]) -> None:
    sets = c.all(f"/v1/appStoreVersionLocalizations/{loc_id}/appScreenshotSets")
    sset = next((s for s in sets if s["attributes"]["screenshotDisplayType"] == DISPLAY), None)
    if sset:
        for shot in c.all(f"/v1/appScreenshotSets/{sset['id']}/appScreenshots"):
            c.request("DELETE", f"/v1/appScreenshots/{shot['id']}")
    else:
        sset = c.post("/v1/appScreenshotSets", {"data": {
            "type": "appScreenshotSets",
            "attributes": {"screenshotDisplayType": DISPLAY},
            "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": loc_id}}},
        }})["data"]
    ids = []
    for f in files:
        data = f.read_bytes()
        shot = c.post("/v1/appScreenshots", {"data": {
            "type": "appScreenshots",
            "attributes": {"fileName": f.name, "fileSize": len(data)},
            "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": sset["id"]}}},
        }})["data"]
        for op in shot["attributes"]["uploadOperations"]:
            chunk = data[op["offset"]:op["offset"] + op["length"]]
            req = urllib.request.Request(op["url"], data=chunk, method=op["method"],
                                         headers={h["name"]: h["value"] for h in op["requestHeaders"]})
            for attempt in range(5):
                try:
                    urllib.request.urlopen(req, timeout=300).read()
                    break
                except (urllib.error.URLError, TimeoutError):
                    if attempt == 4:
                        raise
                    time.sleep(3 * (attempt + 1))
        c.patch(f"/v1/appScreenshots/{shot['id']}", {"data": {
            "type": "appScreenshots", "id": shot["id"],
            "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()},
        }})
        ids.append(shot["id"])
    # Keep filename order (01..06).
    c.request("PATCH", f"/v1/appScreenshotSets/{sset['id']}/relationships/appScreenshots", {
        "data": [{"type": "appScreenshots", "id": i} for i in ids]})


def main() -> None:
    version_id, locales = sys.argv[1], sys.argv[2:]
    c = r.ASC()
    locs = {l["attributes"]["locale"]: l["id"] for l in r.localizations(c, version_id)}
    for loc in locales:
        files = sorted((OUT / loc / "ipad").glob("*.png"))
        if len(files) != 6 or loc not in locs:
            print(f"SKIP {loc}: {len(files)} files, in draft: {loc in locs}")
            continue
        upload(c, locs[loc], files)
        print(f"uploaded {loc}")


if __name__ == "__main__":
    main()
