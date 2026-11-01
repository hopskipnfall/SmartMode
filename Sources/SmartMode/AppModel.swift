import Foundation
import SwiftUI
import SmartModeCore

@MainActor
final class AppModel: ObservableObject {
    @Published var lines: [String] = ["starting…"]
    @Published var configError: String?
    @Published var launchAtLogin = LoginItem.isEnabled
    @Published var loginItemError: String?
    @Published var paused = false {
        didSet { controller.paused = paused }
    }

    static let configURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/smart-mode/config.json")

    private var controller = ModeController(config: .example)
    private var decider = AutoDecider(config: .example)
    private var configModified: Date?
    private let sensor = SensorProvider()
    private let weather = WeatherProvider()
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

        weather.refreshIfNeeded(latitude: config.latitude, longitude: config.longitude, now: now)
        let readings = Readings(
            lux: sensor.read(now: now),
            sunElevation: solarElevation(at: now, latitude: config.latitude, longitude: config.longitude),
            cloudCoverPercent: weather.cloudCover(now: now)
        )
        let decision = decider.decide(readings)

        let system = Applier.current()
        let action = controller.evaluate(decision, system: system, now: now)
        let actionLine: String
        switch action {
        case .hold(let why):
            actionLine = "holding: \(why)"
        case .set(let appearance, let why):
            do {
                try Applier.set(appearance)
                lastApplyError = nil
                actionLine = "switched to \(appearance.rawValue) (\(why))"
            } catch {
                lastApplyError = error.localizedDescription
                actionLine = "switch failed"
            }
        }

        var out: [String] = []
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
        if config.latitude == 0 && config.longitude == 0 { out.append("Set your latitude/longitude in the config") }
        lines = out
    }
}
