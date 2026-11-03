import Foundation
import SmartModeCore

/// The Windows shell around the shared `AppEngine`: the engine decides, this adds launch at login
/// and opening files and links, and the tray and location window read their state from it.
final class AppModel {
    private static let loginDefaultMarker = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/smart-mode/login-default-applied")
    /// Keep in step with the VERSION file.
    static let version = "1.0.0"

    let engine = AppEngine(services: WindowsServices())
    private(set) var loginItemError: String?

    var lines: [String] { engine.lines }
    var configError: String? { engine.configError }
    var locationLabel: String? { engine.locationLabel }
    var locationSaveError: String? { engine.locationSaveError }
    var needsLocation: Bool { engine.needsLocation }
    var paused: Bool {
        get { engine.paused }
        set { engine.paused = newValue }
    }
    var launchAtLogin: Bool { Autostart.isEnabled }
    var onChange: (() -> Void)? {
        get { engine.onChange }
        set { engine.onChange = newValue }
    }

    func start() {
        enableLaunchAtLoginByDefaultOnce()
        engine.tick()
    }

    /// Starts on by default, applied a single time so turning it off afterwards sticks.
    private func enableLaunchAtLoginByDefaultOnce() {
        let marker = Self.loginDefaultMarker
        guard !FileManager.default.fileExists(atPath: marker.path),
              !executablePath().contains("\\.build\\") else { return }
        try? FileManager.default.createDirectory(at: marker.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? Data().write(to: marker)
        setLaunchAtLogin(true)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try Autostart.set(enabled)
            loginItemError = nil
        } catch {
            loginItemError = "Launch at login failed: \(error.localizedDescription)"
        }
        onChange?()
    }

    func tick() { engine.tick() }
    func choose(_ place: Place) { engine.choose(place) }
    func search(_ query: String, completion: @escaping ([Place], Bool) -> Void) { engine.search(query, completion: completion) }
    func openConfig() { Shell.open(AppEngine.configURL.path) }

    func openBugReport() {
        let version = ProcessInfo.processInfo.operatingSystemVersionString
        Shell.open(bugReportURL(version: Self.version, macOS: "Windows (\(version))").absoluteString)
    }
}
