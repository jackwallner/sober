#!/usr/bin/env python3
"""Record the Swift bonsai scenes for the Android parity tests.

The Android app draws the bonsai natively (android/.../ui/bonsai/Bonsai*.kt, a port of
Shared/Bonsai/*.swift). This script compiles the real Swift renderer, paint, scene and wind files
on macOS and records, per layer of each recorded scene: ink, clip chain, wind motion, and how much of
a 2 unit sampling grid (offset off the integer edges) over the 600x600 design square the layer covers (count and centroid). It also
records the wind math. BonsaiParityTest compares the Kotlin port against these within a small
tolerance.

  * android/app/src/test/resources/bonsai/sampled.jsonl.gz   committed scene fixture
  * android/app/src/test/resources/bonsai/wind.jsonl         committed wind fixture
  * android/app/src/test/resources/bonsai/manifest.json      committed, SHA-256 of every Swift bonsai file

Usage:
  scripts/sync-android-bonsai.py          re-record the fixtures and manifest (needs macOS and Xcode)
  scripts/sync-android-bonsai.py --check  exit 1 if a Swift bonsai file changed since the manifest

Changing a Swift bonsai file means porting it to Kotlin first, then re-recording here. Re-recording
without porting makes BonsaiParityTest fail on the scene fixture, which is the point.
"""
from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SWIFT_DIR = ROOT / "Shared/Bonsai"
EXPORTER = ROOT / "scripts/android-bonsai/export-main.swift"
THEME_STUB = ROOT / "Tools/BonsaiAudit/Sources/BonsaiAudit/ThemeStub.swift"
FIXTURE_DIR = ROOT / "android/app/src/test/resources/bonsai"
MANIFEST = FIXTURE_DIR / "manifest.json"
SAMPLED = FIXTURE_DIR / "sampled.jsonl.gz"
WIND = FIXTURE_DIR / "wind.jsonl"

STYLES = ["traditional", "cascade", "windswept", "sakura", "maple", "pine"]
VITALITY_STYLES = ["traditional", "cascade", "windswept"]
TEXTURED_STYLES = ["maple", "pine"]
SAMPLE_DAYS = [*range(0, 11), 14, 21, 30, 45, 60, 90, 120, 180, 270, 300, 364, 365]
# (vitality, days) for VITALITY_STYLES on top of the vitality 1 sweep.
LOW_VITALITY = [(0.4, [8, 100, 365]), (0.0, [365])]
# (scale, days) for the thumbnail levels of detail of the textured styles (scale 1 is the sweep).
LOW_DETAIL = [(0.1, [30, 120, 365]), (0.3, [30, 120, 365])]
SCHEMA_VERSION = 3


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def swift_files() -> list[Path]:
    return sorted(SWIFT_DIR.glob("*.swift"))


def current_hashes() -> dict[str, str]:
    files = {f"Shared/Bonsai/{p.name}": sha256(p.read_bytes()) for p in swift_files()}
    files["scripts/android-bonsai/export-main.swift"] = sha256(EXPORTER.read_bytes())
    return files


def check_manifest() -> bool:
    if not MANIFEST.exists():
        print("No manifest; run scripts/sync-android-bonsai.py", file=sys.stderr)
        return False
    recorded = json.loads(MANIFEST.read_text())["files"]
    current = current_hashes()
    stale = sorted(k for k in current.keys() | recorded.keys() if current.get(k) != recorded.get(k))
    if stale:
        print(
            "Android bonsai fixtures are stale: " + ", ".join(stale) + " changed. "
            "Port the change to the Kotlin files in android/app/src/main/java/**/ui/bonsai/, "
            "then run scripts/sync-android-bonsai.py.",
            file=sys.stderr,
        )
        return False
    print("Android bonsai fixtures match the Swift bonsai files.")
    return True


def replaced(text: str, old: str, new: str, name: str) -> str:
    if text.count(old) != 1:
        raise ValueError(f"{name} changed shape ('{old[:50]}'); update scripts/sync-android-bonsai.py")
    return text.replace(old, new)


def exporter_sources(directory: Path) -> list[Path]:
    """The Swift sources the exporter builds: the real ones, with the scene layers readable and the bend shear captured."""
    out: list[Path] = []
    for path in swift_files():
        text = path.read_text()
        if path.name == "BonsaiScene.swift":
            text = text.replace("fileprivate ", "")
            text = replaced(
                text,
                "struct Layer { var path: Path; var shading: GraphicsContext.Shading; var clip, motion: Int }",
                "struct Layer { var path: Path; var shading: GraphicsContext.Shading; var clip, motion: Int; var ink: BonsaiInk }",
                "BonsaiScene.swift",
            )
            text = replaced(
                text,
                "shading: ink.shading(transform), clip: clip, motion: motion))",
                "shading: ink.shading(transform), clip: clip, motion: motion, ink: ink))",
                "BonsaiScene.swift",
            )
        elif path.name == "BonsaiWind.swift":
            text = replaced(
                text,
                "ctx.concatenate(CGAffineTransform(a: 1, b: 0, c: tan(deg * .pi / 180), d: 1, tx: 0, ty: 0))",
                "exportedShear = tan(deg * .pi / 180)\n        "
                "ctx.concatenate(CGAffineTransform(a: 1, b: 0, c: tan(deg * .pi / 180), d: 1, tx: 0, ty: 0))",
                "BonsaiWind.swift",
            )
            text += "\nnonisolated(unsafe) var exportedShear = 0.0\n"
        elif path.name == "BonsaiRenderer.swift":
            if text.count("#Preview {") != 1:
                raise ValueError("BonsaiRenderer.swift changed shape (#Preview); update scripts/sync-android-bonsai.py")
            text = text.split("#Preview {")[0]
        target = directory / path.name
        target.write_text(text)
        out.append(target)
    stub = directory / "ThemeStub.swift"
    stub.write_text(THEME_STUB.read_text())
    main = directory / "main.swift"
    main.write_text(EXPORTER.read_text())
    return [*out, stub, main]


def build_exporter(directory: Path) -> Path:
    executable = directory / "export"
    subprocess.run(
        [
            "xcrun", "swiftc", "-O", "-swift-version", "5", "-target", "arm64-apple-macos14.0",
            *map(str, exporter_sources(directory)), "-o", str(executable),
        ],
        check=True,
    )
    return executable


def run_export(executable: Path, out: Path, vitality: float, scale: float, styles: list[str], days: list[int]) -> list[dict]:
    subprocess.run(
        [str(executable), str(out), str(vitality), str(scale), ",".join(styles), ",".join(map(str, days))],
        check=True,
    )
    return [json.loads(line) for line in out.read_text().splitlines() if line.strip()]


def compact(frame: dict) -> bytes:
    if not frame["layers"] or len(frame["rect"]) != 4:
        raise ValueError(f"Empty or invalid scene: {frame['style']} day {frame['day']}")
    return json.dumps(frame, separators=(",", ":"), sort_keys=True).encode() + b"\n"


def write_gzip(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "wb") as raw, gzip.GzipFile(fileobj=raw, mode="wb", compresslevel=9, mtime=0) as target:
        target.write(data)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="only verify the manifest against the Swift sources")
    options = parser.parse_args()
    if options.check:
        sys.exit(0 if check_manifest() else 1)

    with tempfile.TemporaryDirectory(prefix="sober-bonsai-export-") as directory:
        work = Path(directory)
        executable = build_exporter(work)
        frames: list[dict] = []
        frames += run_export(executable, work / "base.jsonl", 1.0, 1.0, STYLES, SAMPLE_DAYS)
        for vitality, days in LOW_VITALITY:
            frames += run_export(executable, work / f"v{vitality}.jsonl", vitality, 1.0, VITALITY_STYLES, days)
        for scale, days in LOW_DETAIL:
            frames += run_export(executable, work / f"s{scale}.jsonl", 1.0, scale, TEXTURED_STYLES, days)
        write_gzip(SAMPLED, b"".join(compact(f) for f in frames))

        subprocess.run([str(executable), str(work / "wind.jsonl"), "wind"], check=True)
        wind = (work / "wind.jsonl").read_text().splitlines()
        WIND.write_text("\n".join(json.dumps(json.loads(l), separators=(",", ":"), sort_keys=True) for l in wind) + "\n")

    layers = sum(len(f["layers"]) for f in frames)
    MANIFEST.write_text(json.dumps({
        "schemaVersion": SCHEMA_VERSION,
        "files": current_hashes(),
        "frameCount": len(frames),
        "layerCount": layers,
        "windCount": len(wind),
        "grid": 2.0,
        "gridOffset": [0.137, 0.291],
    }, indent=2) + "\n")
    print(f"Fixture: {len(frames)} scenes, {layers:,} layers, {SAMPLED.stat().st_size:,} bytes; {len(wind)} wind poses.")


if __name__ == "__main__":
    main()
