import Foundation

public enum Action: Equatable {
    case hold(String)
    case set(Appearance, String)

    public var target: Appearance? {
        if case .set(let a, _) = self { return a }
        return nil
    }
}

/// Applies an automatic decision to the system while respecting manual changes:
/// switching waits out a minimum time, and a manual change pauses auto-switching
/// until the automatic decision next flips (or the system matches it again).
public struct ModeController {
    public var config: Config
    public var paused = false
    /// The most recent automatic decision, independent of overrides.
    public private(set) var autoMode: Appearance?
    public private(set) var overridden = false

    private var expected: Appearance?   // what we believe the system appearance currently is
    private var lastSwitch: Date?

    public init(config: Config) {
        self.config = config
    }

    public mutating func evaluate(_ decision: AutoDecision?, system: Appearance, now: Date) -> Action {
        if let expected, expected != system { overridden = true }
        expected = system

        guard let decision else { return .hold("no signals") }

        let previousAuto = autoMode
        let auto = decision.mode
        autoMode = auto

        if overridden, (previousAuto != nil && previousAuto != auto) || system == auto {
            overridden = false
        }

        if paused { return .hold("paused") }
        if overridden { return .hold("manual override until the automatic decision changes") }
        if system == auto { return .hold("in sync (\(auto.rawValue))") }

        if let lastSwitch, now.timeIntervalSince(lastSwitch) < config.minSecondsBetweenSwitches {
            return .hold("waiting out the minimum time between switches")
        }
        lastSwitch = now
        expected = auto
        return .set(auto, decision.reason)
    }
}
