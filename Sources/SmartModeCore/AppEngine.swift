import Foundation

/// What differs per operating system: the appearance setting, the light sensor and the network.
public protocol PlatformServices {
    func currentAppearance() -> Appearance
    func apply(_ appearance: Appearance) throws
    /// A smoothed room reading, or nil when there is no sensor (or it shouldn't vote).
    func readLux(now: Date) -> Double?
    /// Fetches a URL; calls back on the same thread the engine is used from.
    func fetch(_ url: URL, _ completion: @escaping (Data?) -> Void)
}

/// The decision loop shared by the non-macOS apps: read the sun, weather and room, decide, apply,
/// and keep the config file in step. The caller calls `tick()` every 10 seconds and redraws on
/// `onChange`. Use it from one thread only.
public final class AppEngine {
    public static let configURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/smart-mode/config.yaml")

    public private(set) var lines: [String] = ["starting…"]
    public private(set) var configError: String?
    public private(set) var locationLabel: String?
    public private(set) var locationSaveError: String?
    /// Without a location the app can't place the sun, so it does nothing at all.
    public var needsLocation: Bool { locationLabel == nil }
    public var paused = false {
        didSet { controller.paused = paused; onChange?() }
    }
    public var onChange: (() -> Void)?

    private let services: PlatformServices
    private let configURL: URL
    private let weather: WeatherProvider
    private var controller = ModeController(config: .example)
    private var decider = AutoDecider(config: .example)
    private var configModified: Date?
    private var lastApplyError: String?

    public init(services: PlatformServices, configURL: URL = AppEngine.configURL) {
        self.services = services
        self.configURL = configURL
        weather = WeatherProvider(fetch: services.fetch)
        writeExampleConfigIfMissing()
    }

    public func search(_ query: String, completion: @escaping ([Place], Bool) -> Void) {
        searchPlaces(query, fetch: services.fetch, completion: completion)
    }

    /// Writes the chosen place into the config's `location:` section (leaving the rest of the
    /// file alone) and applies it straight away. The config is the only place a location lives.
    public func choose(_ place: Place) {
        do {
            let existing = (try? String(contentsOf: configURL, encoding: .utf8)) ?? Config.defaultFileText
            try FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try configText(existing, settingLocationTo: place).write(to: configURL, atomically: true, encoding: .utf8)
            locationSaveError = nil
        } catch {
            locationSaveError = "Couldn't save the location to config.yaml: \(error.localizedDescription)"
        }
        tick()
    }

    private func writeExampleConfigIfMissing() {
        guard !FileManager.default.fileExists(atPath: configURL.path) else { return }
        try? FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? Config.defaultFileText.write(to: configURL, atomically: true, encoding: .utf8)
    }

    private func reloadConfigIfChanged() {
        let modified = (try? FileManager.default.attributesOfItem(atPath: configURL.path)[.modificationDate]) as? Date
        guard modified != configModified else { return }
        configModified = modified
        do {
            let config = try Config.parse(Data(contentsOf: configURL))
            controller.config = config
            decider.config = config
            configError = nil
        } catch {
            configError = "Config error (using last good): \(error)"
        }
    }

    public func tick(now: Date = Date()) {
        reloadConfigIfChanged()
        let config = controller.config

        let location = resolveLocation(config: config)
        locationLabel = location?.label
        if let location {
            weather.refreshIfNeeded(latitude: location.latitude, longitude: location.longitude, now: now)
        }
        let readings = Readings(
            lux: services.readLux(now: now),
            sunElevation: location.map { solarElevation(at: now, latitude: $0.latitude, longitude: $0.longitude) },
            cloudCoverPercent: location == nil ? nil : weather.cloudCover(now: now)
        )
        let decision = decider.decide(readings)

        let system = services.currentAppearance()
        let action = controller.evaluate(decision, system: system, now: now)
        let actionLine: String
        switch action {
        case .hold(let why):
            actionLine = location == nil ? "doing nothing until a location is set" : "holding: \(why)"
        case .set(let appearance, let why):
            do {
                try services.apply(appearance)
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
