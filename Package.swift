// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "VoiceType",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "VoiceType", targets: ["VoiceType"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.5")
    ],
    targets: [
        .executableTarget(
            name: "VoiceType",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
                "MediaControlBridge"
            ],
            path: "Sources/VoiceType",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path/../Frameworks"
                ])
            ]
        ),
        .target(
            name: "MediaControlBridge",
            path: "Sources/MediaControlBridge",
            publicHeadersPath: "include",
            cSettings: [
                .unsafeFlags(["-fobjc-arc"])
            ]
        ),
        .testTarget(
            name: "VoiceTypeTests",
            dependencies: ["VoiceType", "MediaControlBridge"],
            path: "Tests/VoiceTypeTests"
        )
    ]
)
