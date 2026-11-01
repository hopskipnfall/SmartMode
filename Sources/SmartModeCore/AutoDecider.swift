import Foundation

public struct AutoDecision: Equatable {
    public let mode: Appearance
    /// Why, in plain words, for the menu.
    public let reason: String
    public let sunSummary: String
    public let roomSummary: String

    public init(mode: Appearance, reason: String, sunSummary: String = "", roomSummary: String = "") {
        self.mode = mode
        self.reason = reason
        self.sunSummary = sunSummary
        self.roomSummary = roomSummary
    }
}

/// Decides light or dark from the readings alone:
/// 1. Night (sun, lowered by cloud cover, is below the cutoff) is always dark.
/// 2. Otherwise it's daytime: light, unless the room is dark, which switches to dark.
/// Both the night boundary and the room thresholds have hysteresis, so this is stateful.
public struct AutoDecider {
    /// Once night has begun, the cloud-adjusted sun must rise this far above the cutoff to end it.
    static let nightHysteresisDegrees = 1.0

    public var config: Config
    private var isNight = false
    private var roomIsDark = false

    public init(config: Config) {
        self.config = config
    }

    public mutating func decide(_ r: Readings) -> AutoDecision? {
        guard let elevation = r.sunElevation else { return nil }

        let cloud = min(100, max(0, r.cloudCoverPercent ?? 0))
        let effective = elevation - config.night.cloudDarkeningDegrees * cloud / 100
        let cutoff = config.night.sunBelowDegrees

        if isNight {
            if effective > cutoff + Self.nightHysteresisDegrees { isNight = false }
        } else if effective < cutoff {
            isNight = true
        }

        let sunSummary = String(format: "Sun: %.1f° elevation, ", elevation)
            + (r.cloudCoverPercent.map { String(format: "%.0f%% cloud", $0) } ?? "cloud n/a")
            + String(format: " (%.1f° adjusted)", effective)

        let lux = r.lux.map { $0 * config.room.luxScale }
        let roomSummary = lux.map { String(format: "Room: %.1f lux", $0) } ?? "Room: no sensor reading"

        if isNight {
            return AutoDecision(mode: .dark,
                                reason: String(format: "night (sun %.1f° adjusted, below %.1f°)", effective, cutoff),
                                sunSummary: sunSummary, roomSummary: roomSummary)
        }

        guard let lux else {
            roomIsDark = false
            return AutoDecision(mode: .light, reason: "daytime, no light sensor reading",
                                sunSummary: sunSummary, roomSummary: roomSummary)
        }
        if !roomIsDark, lux <= config.room.darkBelowLux {
            roomIsDark = true
        } else if roomIsDark, lux >= config.room.lightAboveLux {
            roomIsDark = false
        }
        return AutoDecision(
            mode: roomIsDark ? .dark : .light,
            reason: roomIsDark ? "daytime, but the room is dark" : "daytime, room is bright enough",
            sunSummary: sunSummary, roomSummary: roomSummary)
    }
}
