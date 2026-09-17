// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AutoMacro",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "AutoMacro",
            path: "AutoMacro",
            exclude: [
                "Assets.xcassets",
                "AutoMacro.entitlements",
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
