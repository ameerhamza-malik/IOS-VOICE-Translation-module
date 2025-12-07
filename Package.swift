// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TranslationModule",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "TranslationModule", targets: ["TranslationModule"])
    ],
    dependencies: [
        .package(url: "https://github.com/argmax-inc/WhisperKit.git", from: "0.2.0")
    ],
    targets: [
        .target(
            name: "TranslationModule",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit")
            ],
            path: ".",
            exclude: ["requirements.txt", "README.md", "walkthrough.md", "task.md", "implementation_plan.md"],
            sources: ["TranslationApp.swift", "Views", "Services", "Models"]
        )
    ]
)
