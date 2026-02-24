// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ASR4me",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ASR4me", targets: ["ASR4me"])
    ],
    targets: [
        .executableTarget(
            name: "ASR4me",
            path: "Sources/ASR4me"
        )
    ]
)
