// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CodexRTLHelper",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Codex-RTL-Helper", targets: ["CodexRTLHelper"]),
        .executable(name: "Codex-RTL-SelfTest", targets: ["CodexRTLSelfTest"]),
        .executable(name: "Codex-RTL-LiveProbe", targets: ["CodexRTLLiveProbe"])
    ],
    targets: [
        .target(
            name: "CodexRTLCore",
            path: "Sources/CodexRTLCore",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "CodexRTLHelper",
            dependencies: ["CodexRTLCore"],
            path: "Sources/CodexRTLHelper"
        ),
        .executableTarget(
            name: "CodexRTLSelfTest",
            dependencies: ["CodexRTLCore"],
            path: "Sources/CodexRTLSelfTest"
        ),
        .executableTarget(
            name: "CodexRTLLiveProbe",
            dependencies: ["CodexRTLCore"],
            path: "Sources/CodexRTLLiveProbe"
        )
    ],
    swiftLanguageModes: [.v5]
)
