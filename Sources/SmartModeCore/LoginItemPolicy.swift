import Foundation

/// Whether to register SmartMode as a login item automatically. It does so once, and only when
/// the app is installed in an Applications folder: a copy in Downloads, the build folder or a
/// quarantine "translocation" path would register a location that won't be there later.
/// The caller records that it applied the default, so turning the item off afterwards sticks.
public func shouldEnableLoginItemByDefault(alreadyApplied: Bool, bundlePath: String, homeDirectory: String) -> Bool {
    guard !alreadyApplied else { return false }
    let folders = ["/Applications/", homeDirectory.hasSuffix("/") ? homeDirectory + "Applications/" : homeDirectory + "/Applications/"]
    return folders.contains { bundlePath.hasPrefix($0) }
}
