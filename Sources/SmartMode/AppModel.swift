import Foundation
import SwiftUI
import SmartModeCore

@MainActor
final class AppModel: ObservableObject {
    @Published var lines: [String] = ["starting…"]
    @Published var configError: String?
    @Published var launchAtLogin = LoginItem.isEnabled
    @Published var loginItemError: String?
    @Published var locationLabel: String?
    @Published var locationSaveError: String?
    @Published var availableUpdate: AvailableUpdate?

    /// Without a location the app can't place the sun, so it does nothing at all.
    var needsLocation: Bool { locationLabel == nil }
    @Published var paused = false {
        didSet { controller.paused = paused }
    }

    static let configURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/smart-mode/config.yaml")

    private var controller = ModeController(config: .example)
    private var decider = AutoDecider(config: .example)
    private var configModified: Date?
    private let sensor = SensorProvider()
    private let weather = WeatherProvider()
    private let updates = UpdateChecker()
    private var timer: Timer?
    private var lastApplyError: String?

    init() {
        writeExampleConfigIfMissing()
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LoginItem.set(enabled)
            loginItemError = nil
        } catch {
            loginItemError = "Launch at login failed: \(error.localizedDescription)"
        }
        launchAtLogin = LoginItem.isEnabled
    }

    func openLocationWindow() {
        LocationWindowController.shared.show(model: self)
    }

    /// Writes the chosen place into the config file's `location:` section (leaving the rest of
    /// the file alone) and applies it straight away. The config is the only place a location lives.
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

    func openUpdate(_ update: AvailableUpdate) {
        NSWorkspace.shared.open(update.url)
    }

    /// Opens GitHub's new-bug-report form with the SmartMode and macOS versions filled in.
    func openBugReport() {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let macOS = "macOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        NSWorkspace.shared.open(bugReportURL(version: updates.currentVersion ?? "unknown", macOS: macOS))
    }

    private func refreshAvailableUpdate() {
        availableUpdate = controller.config.checkForUpdates ? updates.available : nil
    }

    func openConfig() {
        NSWorkspace.shared.open(Self.configURL)
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

        if config.checkForUpdates {
            updates.checkIfDue(now: now) { [weak self] in self?.refreshAvailableUpdate() }
        }
        refreshAvailableUpdate()

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
        if let location {
            out.append("Location: \(location.label)")
        }
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
    }
}
