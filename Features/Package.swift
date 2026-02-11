// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Features",
    platforms: [
        .iOS(.v17), .macOS(.v14)
    ],
    products: [
        .singleTargetLibrary("AppFeature"),
        .singleTargetLibrary("AppSchemas"),
        .singleTargetLibrary("UIComponents"),
        .singleTargetLibrary("AudioEngineClient"),
        .singleTargetLibrary("AudioEngineClientLive"),
        .singleTargetLibrary("ComposeFeature"),
        .singleTargetLibrary("DiscoverFeature"),
        .singleTargetLibrary("LibraryFeature"),
        .singleTargetLibrary("SettingsFeature"),
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/AudioKit/AudioKit.git",
            branch: "main"
        )
    ],
    targets: [
        .target(
            name: "AppFeature",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                "AppSchemas",
                "AudioKit",
                "AudioEngineClient",
                "AudioEngineClientLive",
                "ComposeFeature",
                "DiscoverFeature",
                "LibraryFeature",
                "SettingsFeature"
            ]
        ),
        .target(
            name: "AppSchemas",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                "AudioKit"
            ]
        ),
        .target(
            name: "UIComponents",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                "AppSchemas",
                "AudioEngineClient"
            ]
        ),
        .target(
            name: "AudioEngineClient",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                "AppSchemas",
                "AudioKit"
            ]
        ),
        .target(
            name: "AudioEngineClientLive",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                "AudioEngineClient",
                "AudioKit"
            ],
            resources: [
                .process("Resources", localization: .none)
            ]
        ),
        .target(
            name: "ComposeFeature",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                "AudioEngineClient",
                "UIComponents"
            ]
        ),
        .target(
            name: "DiscoverFeature",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .target(
            name: "LibraryFeature",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .target(
            name: "SettingsFeature",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
    ]
)

extension Product {
    static func singleTargetLibrary(_ name: String) -> Product {
        .library(name: name, targets: [name])
    }
}
