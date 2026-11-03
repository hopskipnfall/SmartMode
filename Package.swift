// swift-tools-version: 5.10
import PackageDescription

#if os(macOS)
let platformTargets: [Target] = [
    .target(
        name: "SensorShim",
        linkerSettings: [.linkedFramework("IOKit"), .linkedFramework("CoreFoundation")]
    ),
    .executableTarget(name: "SmartModeProbe", dependencies: ["SensorShim"]),
    .executableTarget(name: "SmartMode", dependencies: ["SmartModeCore", "SensorShim"], path: "Sources/SmartModeMac"),
]
#elseif os(Linux)
let platformTargets: [Target] = [
    // GTK 3 and the Ayatana AppIndicator library (libgtk-3-dev, libayatana-appindicator3-dev).
    .systemLibrary(name: "CGtk", pkgConfig: "gtk+-3.0 ayatana-appindicator3-0.1"),
    .executableTarget(name: "SmartModeLinux", dependencies: ["SmartModeCore", "CGtk"]),
]
#else
let platformTargets: [Target] = []
#endif

let package = Package(
    name: "smart-mode",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.3"),
    ],
    targets: [
        .target(name: "SmartModeCore", dependencies: ["Yams"]),
        .testTarget(name: "SmartModeCoreTests", dependencies: ["SmartModeCore"]),
    ] + platformTargets
)
