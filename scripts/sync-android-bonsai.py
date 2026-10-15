#!/usr/bin/env python3
"""Record the original Swift bonsai renderer's drawing commands for the Android parity tests.

The Android app draws bonsai natively (android/.../ui/bonsai/BonsaiRenderer.kt, a line-for-line
port). This script compiles the Swift renderer core against a recording shim
(scripts/android-bonsai/RecordingGraphics.swift) and dumps what it draws:

  * android/app/src/test/resources/bonsai/sampled.jsonl.gz   committed, sampled days (+ low vitality)
  * android/app/src/test/resources/bonsai/manifest.json      committed, renderer source SHA-256
  * android/app/build/bonsai-full/<style>.jsonl.gz           gitignored, every day 0...365 x 6 styles

Usage:
  scripts/sync-android-bonsai.py            regenerate fixture + manifest + full export
  scripts/sync-android-bonsai.py --no-full  fixture + manifest only (skips the full export)
  scripts/sync-android-bonsai.py --check    exit 1 if the Swift renderer changed since the manifest
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
SOURCE = ROOT / "Shared/Bonsai/BonsaiRenderer.swift"
ADAPTER = ROOT / "scripts/android-bonsai/RecordingGraphics.swift"
FIXTURE_DIR = ROOT / "android/app/src/test/resources/bonsai"
MANIFEST = FIXTURE_DIR / "manifest.json"
SAMPLED = FIXTURE_DIR / "sampled.jsonl.gz"
FULL_DIR = ROOT / "android/app/build/bonsai-full"

STYLES = ["traditional", "cascade", "windswept", "sakura", "maple", "pine"]
# Styles whose foliage is dimmed by vitality (Swift satFactor).
VITALITY_STYLES = ["traditional", "cascade", "windswept"]
SAMPLE_DAYS = [*range(0, 11), 14, 21, 30, 45, 60, 90, 120, 180, 270, 300, 364, 365]
# (vitality, days) recorded for VITALITY_STYLES on top of the vitality 1 sweep.
LOW_VITALITY = [(0.4, [8, 100, 365]), (0.0, [365])]
SCHEMA_VERSION = 2

MAIN = r'''
import Foundation

// usage: export <outdir> <vitality> <styles|all> <days|all>
let args = CommandLine.arguments
let output = URL(fileURLWithPath: args[1])
let vitality = Double(args[2])!
let styles = args[3] == "all"
    ? BonsaiStyle.allCases
    : args[3].split(separator: ",").map { BonsaiStyle(rawValue: String($0))! }
let days: [Int] = args[4] == "all" ? Array(0...365) : args[4].split(separator: ",").map { Int($0)! }

try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for style in styles {
    var lines = Data()
    for day in days {
        let record = DrawingRecord()
        var context = GraphicsContext(record: record)
        exportedDrawBonsai(day: day, style: style, vitality: vitality, in: &context)
        let bounds = bonsaiContentRect(day: day, style: style)
        let frame: [String: Any] = [
            "day": day, "style": style.rawValue, "vitality": vitality,
            "bounds": [bounds.minX, bounds.minY, bounds.width, bounds.height],
            "commands": record.commands,
        ]
        lines.append(try JSONSerialization.data(withJSONObject: frame, options: [.sortedKeys]))
        lines.append(10)
    }
    try lines.write(to: output.appendingPathComponent("\(style.rawValue).jsonl"))
}
'''


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def renderer_core(text: str) -> str:
    """The Swift file minus its SwiftUI view, plus the view's draw body as a plain function."""
    marker = "// MARK: - Public View"
    if text.count(marker) != 1:
        raise ValueError("Review the changed Swift renderer before exporting its drawing core")
    core, view = text.split(marker, 1)
    start = view.index("            if style == .sakura {")
    end = view.index("\n        }\n        .accessibilityLabel", start)
    body = view[start:end]
    if body.count("let satFactor =") != 1:
        raise ValueError("Review the renderer's foliage boundary before exporting vitality")
    core = core.replace("import SwiftUI", "import CoreGraphics\nimport Foundation")
    return (
        core
        + "\nfunc exportedDrawBonsai(day: Int, style: BonsaiStyle, vitality: Double, in ctx: inout GraphicsContext) {\n"
        + body
        + "\n}\n"
    )


def check_manifest() -> bool:
    if not MANIFEST.exists():
        print("No manifest; run scripts/sync-android-bonsai.py", file=sys.stderr)
        return False
    manifest = json.loads(MANIFEST.read_text())
    current = {"sourceSHA256": sha256(SOURCE.read_bytes()), "adapterSHA256": sha256(ADAPTER.read_bytes())}
    stale = [key for key, value in current.items() if manifest.get(key) != value]
    if stale:
        print(
            f"Android bonsai fixture is stale ({', '.join(stale)} changed). "
            "Port the change to BonsaiRenderer.kt, then run scripts/sync-android-bonsai.py.",
            file=sys.stderr,
        )
        return False
    print("Android bonsai fixture matches the Swift renderer.")
    return True


def build_exporter(temporary: Path) -> Path:
    (temporary / "RendererCore.swift").write_text(renderer_core(SOURCE.read_text()))
    (temporary / "main.swift").write_text(MAIN)
    executable = temporary / "export"
    subprocess.run(
        [
            "xcrun", "swiftc", "-O", "-target", "arm64-apple-macos14.0",
            str(ADAPTER), str(temporary / "RendererCore.swift"), str(temporary / "main.swift"),
            "-o", str(executable),
        ],
        check=True,
    )
    return executable


def run_export(executable: Path, out: Path, vitality: float, styles: str, days: str) -> None:
    subprocess.run([str(executable), str(out), str(vitality), styles, days], check=True)


def write_gzip(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "wb") as raw, gzip.GzipFile(fileobj=raw, mode="wb", compresslevel=9, mtime=0) as target:
        target.write(data)


def compact(line: bytes) -> bytes:
    frame = json.loads(line)
    if not frame["commands"] or len(frame["bounds"]) != 4:
        raise ValueError(f"Empty or invalid drawing: {frame['style']} day {frame['day']}")
    return json.dumps(frame, separators=(",", ":"), sort_keys=True).encode() + b"\n"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="only verify the manifest against the Swift source")
    parser.add_argument("--no-full", action="store_true", help="skip the gitignored full export")
    options = parser.parse_args()
    if options.check:
        sys.exit(0 if check_manifest() else 1)

    source_hash = sha256(SOURCE.read_bytes())
    adapter_hash = sha256(ADAPTER.read_bytes())
    with tempfile.TemporaryDirectory(prefix="sober-bonsai-export-") as directory:
        temporary = Path(directory)
        executable = build_exporter(temporary)

        full = temporary / "full"
        run_export(executable, full, 1.0, "all", "all")
        sampled_lines: list[bytes] = []
        full_frames = 0
        for style in STYLES:
            lines = (full / f"{style}.jsonl").read_bytes().splitlines()
            full_frames += len(lines)
            sampled_lines += [compact(l) for l in lines if json.loads(l)["day"] in SAMPLE_DAYS]
        if full_frames != len(STYLES) * 366:
            raise ValueError(f"Expected {len(STYLES) * 366} frames, got {full_frames}")

        low_frames = 0
        for vitality, days in LOW_VITALITY:
            low = temporary / f"vitality-{vitality}"
            run_export(executable, low, vitality, ",".join(VITALITY_STYLES), ",".join(map(str, days)))
            for style in VITALITY_STYLES:
                lines = (low / f"{style}.jsonl").read_bytes().splitlines()
                sampled_lines += [compact(l) for l in lines]
                low_frames += len(lines)

        write_gzip(SAMPLED, b"".join(sampled_lines))
        manifest = {
            "schemaVersion": SCHEMA_VERSION,
            "source": "Shared/Bonsai/BonsaiRenderer.swift",
            "sourceSHA256": source_hash,
            "adapterSHA256": adapter_hash,
            "styles": STYLES,
            "fullFrameCount": full_frames,
            "sampledFrameCount": len(sampled_lines),
            "sampledDays": SAMPLE_DAYS,
            "lowVitality": [{"vitality": v, "days": d, "styles": VITALITY_STYLES} for v, d in LOW_VITALITY],
        }
        MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n")
        print(f"Fixture: {len(sampled_lines)} frames ({low_frames} low vitality), {SAMPLED.stat().st_size:,} bytes.")

        if not options.no_full:
            for style in STYLES:
                write_gzip(FULL_DIR / f"{style}.jsonl.gz", b"".join(compact(l) for l in (full / f"{style}.jsonl").read_bytes().splitlines()))
            (FULL_DIR / "manifest.json").write_text(
                json.dumps({"sourceSHA256": source_hash, "frameCount": full_frames}, indent=2) + "\n"
            )
            total = sum(p.stat().st_size for p in FULL_DIR.glob("*.jsonl.gz"))
            print(f"Full export: {full_frames} frames, {total:,} bytes in {FULL_DIR.relative_to(ROOT)}.")


if __name__ == "__main__":
    main()
