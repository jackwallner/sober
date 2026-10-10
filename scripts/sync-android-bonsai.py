#!/usr/bin/env python3
"""Export every daily native bonsai directly from the original Swift renderer."""
from __future__ import annotations

import hashlib
import json
import subprocess
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "Shared/Bonsai/BonsaiRenderer.swift"
ADAPTER = ROOT / "scripts/android-bonsai/RecordingGraphics.swift"
ASSETS = ROOT / "android/app/src/main/assets"

MAIN = r'''
import Foundation

let output = URL(fileURLWithPath: CommandLine.arguments[1])
for style in BonsaiStyle.allCases {
    let directory = output.appendingPathComponent(style.rawValue)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    for day in 0...365 {
        let record = DrawingRecord()
        var context = GraphicsContext(record: record)
        exportedDrawBonsai(day: day, style: style, vitality: 1, in: &context)
        let bounds = bonsaiContentRect(day: day, style: style)
        let frame: [String: Any] = [
            "day": day, "style": style.rawValue,
            "bounds": [bounds.minX, bounds.minY, bounds.width, bounds.height],
            "foliageStart": record.foliageStart,
            "commands": record.commands,
        ]
        let data = try JSONSerialization.data(withJSONObject: frame, options: [.sortedKeys])
        try data.write(to: directory.appendingPathComponent(String(format: "%03d.json", day)))
    }
    print("Exported every day 0...365 for \(style.rawValue)")
}
'''


def renderer_core(text: str) -> str:
    marker = "// MARK: - Public View"
    if text.count(marker) != 1:
        raise ValueError("Review the changed Swift renderer before exporting its drawing core")
    core, view = text.split(marker, 1)
    start = view.index("            if style == .sakura {")
    end = view.index("\n        }\n        .accessibilityLabel", start)
    body = view[start:end]
    if body.count("let satFactor =") != 1:
        raise ValueError("Review the renderer's foliage boundary before exporting vitality")
    body = body.replace("            let satFactor =", "            ctx.record.foliageStart = ctx.record.commands.count\n            let satFactor =")
    core = core.replace("import SwiftUI", "import CoreGraphics\nimport Foundation")
    return core + "\nfunc exportedDrawBonsai(day: Int, style: BonsaiStyle, vitality: Double, in ctx: inout GraphicsContext) {\n" + body + "\n}\n"


def main() -> None:
    source = SOURCE.read_text()
    core = renderer_core(source)
    ASSETS.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="sober-bonsai-export-") as directory:
        temporary = Path(directory)
        (temporary / "RendererCore.swift").write_text(core)
        (temporary / "main.swift").write_text(MAIN)
        executable = temporary / "export"
        subprocess.run([
            "xcrun", "swiftc", "-O", "-target", "arm64-apple-macos14.0",
            str(ADAPTER), str(temporary / "RendererCore.swift"), str(temporary / "main.swift"),
            "-o", str(executable),
        ], check=True)
        frames = temporary / "frames"
        subprocess.run([str(executable), str(frames)], check=True)
        files = sorted(frames.glob("*/*.json"))
        if len(files) != 6 * 366:
            raise ValueError(f"Expected 2,196 daily native frames, got {len(files)}")
        archive = ASSETS / "bonsai.zip"
        with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as target:
            for path in files:
                frame = json.loads(path.read_text())
                if not frame["commands"] or len(frame["bounds"]) != 4:
                    raise ValueError(f"Empty or invalid drawing: {path.relative_to(frames)}")
                target.write(path, path.relative_to(frames).as_posix())
        metadata = {
            "schemaVersion": 1,
            "source": "Shared/Bonsai/BonsaiRenderer.swift",
            "sourceSHA256": hashlib.sha256(source.encode()).hexdigest(),
            "adapterSHA256": hashlib.sha256(ADAPTER.read_bytes()).hexdigest(),
            "frameCount": len(files),
            "styles": ["traditional", "cascade", "windswept", "sakura", "maple", "pine"],
            "days": [0, 365],
            "archiveSHA256": hashlib.sha256(archive.read_bytes()).hexdigest(),
            "archiveBytes": archive.stat().st_size,
        }
        (ASSETS / "bonsai-manifest.json").write_text(json.dumps(metadata, indent=2) + "\n")
        print(f"Verified {len(files)} original-Swift drawing frames, {archive.stat().st_size:,} archive bytes.")


if __name__ == "__main__":
    main()
