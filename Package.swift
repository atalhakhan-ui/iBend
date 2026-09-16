// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "iBend",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "iBend",
            path: "Sources/iBend"
        )
    ]
)
