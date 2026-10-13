// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "HearviaKit",
    platforms: [.iOS("27.0"), .macOS("27.0")],
    products: [
        .library(name: "HearviaKit", targets: ["HearviaKit"]),
        .executable(name: "hearvia-translate", targets: ["hearvia-translate"]),
    ],
    targets: [
        .target(name: "HearviaKit"),
        .executableTarget(name: "hearvia-translate", dependencies: ["HearviaKit"]),
        .testTarget(name: "HearviaKitTests", dependencies: ["HearviaKit"]),
    ]
)
