// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "HearviaKit",
    platforms: [.iOS("27.0"), .macOS("27.0")],
    products: [
        // One product for the apps; each file imports only the modules it uses.
        .library(name: "HearviaKit", targets: ["HearviaCore", "HearviaAudio", "HearviaEngines", "HearviaSession", "HearviaUI"]),
        .executable(name: "hearvia-translate", targets: ["hearvia-translate"])
    ],
    targets: [
        .target(name: "HearviaCore"),
        .target(name: "HearviaAudio"),
        .target(name: "HearviaEngines", dependencies: ["HearviaCore", "HearviaAudio"]),
        .target(name: "HearviaSession", dependencies: ["HearviaCore", "HearviaAudio", "HearviaEngines"]),
        .target(name: "HearviaUI", dependencies: ["HearviaCore", "HearviaEngines"]),
        .executableTarget(name: "hearvia-translate", dependencies: ["HearviaAudio", "HearviaEngines"]),
        .testTarget(name: "HearviaCoreTests", dependencies: ["HearviaCore"]),
        .testTarget(name: "HearviaAudioTests", dependencies: ["HearviaAudio"]),
        .testTarget(name: "HearviaEnginesTests", dependencies: ["HearviaEngines"]),
        .testTarget(name: "HearviaSessionTests", dependencies: ["HearviaSession"])
    ]
)
