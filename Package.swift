// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "smart-mode",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.3"),
    ],
    targets: [
        .target(
            name: "SensorShim",
            linkerSettings: [.linkedFramework("IOKit"), .linkedFramework("CoreFoundation")]
        ),
        .target(name: "SmartModeCore", dependencies: ["Yams"]),
        .executableTarget(name: "SmartModeProbe", dependencies: ["SensorShim"]),
        .executableTarget(name: "SmartMode", dependencies: ["SmartModeCore", "SensorShim"]),
        .testTarget(name: "SmartModeCoreTests", dependencies: ["SmartModeCore"]),
    ]
)
