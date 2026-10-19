// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Wizclip",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Wizclip",
            path: "Wizclip",
            exclude: [
                "Info.plist",
                "Assets.xcassets",
                "Resources"
            ]
        )
    ]
)
