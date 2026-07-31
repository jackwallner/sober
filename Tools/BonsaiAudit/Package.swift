// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BonsaiAudit",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "BonsaiAudit", swiftSettings: [.swiftLanguageMode(.v5)])
    ]
)
