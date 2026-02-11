// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TranscribeHoldPaste",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "TranscribeHoldPasteKit", targets: ["TranscribeHoldPasteKit"]),
        .executable(name: "TranscribeHoldPasteCLI", targets: ["TranscribeHoldPasteCLI"]),
        .executable(name: "TranscribeHoldPasteApp", targets: ["TranscribeHoldPasteApp"]),
    ],
    targets: [
        .target(
            name: "TranscribeHoldPasteKit"
        ),
        .executableTarget(
            name: "TranscribeHoldPasteCLI",
            dependencies: ["TranscribeHoldPasteKit"]
        ),
        .executableTarget(
            name: "TranscribeHoldPasteApp",
            dependencies: ["TranscribeHoldPasteKit"]
        ),
    ]
)
