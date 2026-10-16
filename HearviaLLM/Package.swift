// swift-tools-version: 6.2
import PackageDescription

/// Open-weight on-device models, kept out of HearviaKit so its tests stay fast and MLX-free.
/// MLX compiles Metal shaders only under Xcode: build with xcodebuild, not `swift build`.
let package = Package(
    name: "HearviaLLM",
    platforms: [.iOS("27.0"), .macOS("27.0")],
    products: [
        .library(name: "HearviaGemma", targets: ["HearviaGemma"]),
        .executable(name: "gemma-bench", targets: ["gemma-bench"])
    ],
    dependencies: [
        .package(path: "../HearviaKit"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", .upToNextMinor(from: "3.32.3")),
        .package(url: "https://github.com/huggingface/swift-huggingface", from: "1.0.0"),
        .package(url: "https://github.com/huggingface/swift-transformers", from: "1.3.5")
    ],
    targets: [
        .target(name: "HearviaGemma", dependencies: [
            .product(name: "HearviaKit", package: "HearviaKit"),
            .product(name: "MLXLLM", package: "mlx-swift-lm"),
            .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
            .product(name: "HuggingFace", package: "swift-huggingface"),
            .product(name: "Tokenizers", package: "swift-transformers")
        ]),
        .executableTarget(name: "gemma-bench", dependencies: ["HearviaGemma"])
    ]
)
