import Foundation
import SmartModeCore

/// The decision loop: every 10 seconds read the sun, weather and room, decide, and apply.
/// Mirrors the macOS app's AppModel; the UI redraws through `onChange`. Main thread only.
final class AppModel {
    static let configURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/smart-mode/config.yaml")
    private static let loginDefaultMarker = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/smart-mode/login-default-applied")
    /// Keep in step with the VERSION file.
    static let version = "1.0.0"

    private(set) var lines: [String] = ["starting…"]
    private(set) var configError: String?
    private(set) var locationLabel: String?
    private(set) var locationSaveError: String?
    private(set) var loginItemError: String?
    var needsLocation: Bool { locationLabel == nil }
    var paused = false {
        didSet { controller.paused = paused; onChange?() }
    }
    var launchAtLogin: Bool { Autostart.isEnabled }
    var onChange: (() -> Void)?

    private var controller = ModeController(config: .example)
    private var decider = AutoDecider(config: .example)
    private var configModified: Date?
    private let sensor = SensorProvider()
    private let weather = WeatherProvider()
    private var lastApplyError: String?

    func start() {
        writeExampleConfigIfMissing()
        enableLaunchAtLoginByDefaultOnce()
        tick()
        every(seconds: 10) { [self] in tick() }
    }

    /// Starts on by default, applied a single time so turning it off afterwards sticks.
    private func enableLaunchAtLoginByDefaultOnce() {
        let marker = Self.loginDefaultMarker
        guard !FileManager.default.fileExists(atPath: marker.path),
              !Autostart.executablePath.contains("/.build/") else { return }
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

    /// Writes the chosen place into the config's `location:` section and applies it straight away.
    func choose(_ place: Place) {
        let url = Self.configURL
        do {
            let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? Config.defaultFileText
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try configText(existing, settingLocationTo: place).write(to: url, atomically: true, encoding: .utf8)
            locationSaveError = nil
        } catch {
            locationSaveError = "Couldn't save the location to config.yaml: \(error.localizedDescription)"
        }
        tick()
    }

    func openConfig() { Shell.open(Self.configURL.path) }

    func openBugReport() {
        let desktop = ProcessInfo.processInfo.environment["XDG_CURRENT_DESKTOP"] ?? "unknown desktop"
        Shell.open(bugReportURL(version: Self.version, macOS: "Linux (\(desktop))").absoluteString)
    }

    private func writeExampleConfigIfMissing() {
        let url = Self.configURL
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? Config.defaultFileText.write(to: url, atomically: true, encoding: .utf8)
    }

    private func reloadConfigIfChanged() {
        let url = Self.configURL
        let modified = (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date
        guard modified != configModified else { return }
        configModified = modified
        do {
            let config = try Config.parse(Data(contentsOf: url))
            controller.config = config
            decider.config = config
            configError = nil
        } catch {
            configError = "Config error (using last good): \(error)"
        }
    }

    private func tick() {
        let now = Date()
        reloadConfigIfChanged()
        let config = controller.config

        let location = resolveLocation(config: config)
        locationLabel = location?.label
        if let location {
            weather.refreshIfNeeded(latitude: location.latitude, longitude: location.longitude, now: now)
        }
        let readings = Readings(
            lux: sensor.read(now: now),
            sunElevation: location.map { solarElevation(at: now, latitude: $0.latitude, longitude: $0.longitude) },
            cloudCoverPercent: location == nil ? nil : weather.cloudCover(now: now)
        )
        let decision = decider.decide(readings)

        let system = Applier.current()
        let action = controller.evaluate(decision, system: system, now: now)
        let actionLine: String
        switch action {
        case .hold(let why):
            actionLine = location == nil ? "doing nothing until a location is set" : "holding: \(why)"
        case .set(let appearance, let why):
            do {
                try Applier.set(appearance)
                controller.didApply(appearance, at: now)
                lastApplyError = nil
                actionLine = "switched to \(appearance.rawValue) (\(why))"
            } catch {
                lastApplyError = error.localizedDescription
                actionLine = "switch failed"
            }
        }

        var out: [String] = []
        if let location { out.append("Location: \(location.label)") }
        out.append("Now: \(system.rawValue) · \(actionLine)")
        if let decision {
            out.append("Decision: \(decision.mode.rawValue), \(decision.reason)")
            out.append("  \(decision.sunSummary)")
            out.append("  \(decision.roomSummary)")
        } else {
            out.append("Decision: none yet")
        }
        if controller.overridden { out.append("Manual override active") }
        if let lastApplyError { out.append("Apply error: \(lastApplyError)") }
        lines = out
        onChange?()
    }
}
