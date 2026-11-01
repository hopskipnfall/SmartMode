import Foundation
import Testing
@testable import SmartModeCore

extension ModeController {
    /// Evaluates and, when it asks for a switch, reports that the switch succeeded.
    mutating func evaluateAndApply(_ decision: AutoDecision?, system: Appearance, now: Date) -> Action {
        let action = evaluate(decision, system: system, now: now)
        if case .set(let appearance, _) = action { didApply(appearance, at: now) }
        return action
    }
}

struct ModeControllerTests {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)
    private func controller() -> ModeController {
        var config = Config(latitude: 0, longitude: 0)
        config.minSecondsBetweenSwitches = 600
        return ModeController(config: config)
    }
    private func auto(_ mode: Appearance) -> AutoDecision {
        AutoDecision(mode: mode, reason: "test")
    }

    @Test func firstEvaluationSetsWhenOutOfSync() {
        var c = controller()
        #expect(c.evaluateAndApply(auto(.dark), system: .light, now: t0).target == .dark)
    }

    @Test func firstEvaluationInSyncHolds() {
        var c = controller()
        #expect(c.evaluateAndApply(auto(.light), system: .light, now: t0).target == nil)
    }

    @Test func noSignalsHolds() {
        var c = controller()
        #expect(c.evaluateAndApply(nil, system: .light, now: t0).target == nil)
    }

    @Test func repeatedSameDecisionHolds() {
        var c = controller()
        _ = c.evaluateAndApply(auto(.dark), system: .light, now: t0)              // -> dark
        #expect(c.evaluateAndApply(auto(.dark), system: .dark, now: t0 + 1000).target == nil)
        #expect(c.evaluateAndApply(auto(.dark), system: .dark, now: t0 + 2000).target == nil)
    }

    @Test func switchesBackBelowLightThresholdAfterDwell() {
        var c = controller()
        _ = c.evaluateAndApply(auto(.dark), system: .light, now: t0)
        #expect(c.evaluateAndApply(auto(.light), system: .dark, now: t0 + 700).target == .light)
    }

    @Test func dwellBlocksRapidSecondSwitch() {
        var c = controller()
        _ = c.evaluateAndApply(auto(.dark), system: .light, now: t0)
        #expect(c.evaluateAndApply(auto(.light), system: .dark, now: t0 + 100).target == nil)  // too soon
        #expect(c.evaluateAndApply(auto(.light), system: .dark, now: t0 + 700).target == .light) // retries later
    }

    @Test func manualChangeSuppressesSwitching() {
        var c = controller()
        _ = c.evaluateAndApply(auto(.dark), system: .light, now: t0)       // app sets dark
        // user flips to light manually while score still says dark
        #expect(c.evaluateAndApply(auto(.dark), system: .light, now: t0 + 1000).target == nil)
        #expect(c.overridden)
        #expect(c.evaluateAndApply(auto(.dark), system: .light, now: t0 + 2000).target == nil)
    }

    @Test func overrideEndsWhenAutoDecisionNextFlips() {
        var c = controller()
        _ = c.evaluateAndApply(auto(.dark), system: .light, now: t0)        // dark
        _ = c.evaluateAndApply(auto(.dark), system: .light, now: t0 + 1000) // manual -> light, overridden
        // score drops below the light threshold: auto flips dark->light, which matches system
        #expect(c.evaluateAndApply(auto(.light), system: .light, now: t0 + 2000).target == nil)
        #expect(!c.overridden)
        // next flip to dark is honored again
        #expect(c.evaluateAndApply(auto(.dark), system: .light, now: t0 + 3000).target == .dark)
    }

    @Test func overrideClearsWhenSystemMatchesAutoAgain() {
        var c = controller()
        _ = c.evaluateAndApply(auto(.dark), system: .light, now: t0)         // dark
        _ = c.evaluateAndApply(auto(.dark), system: .light, now: t0 + 1000)  // manual light
        _ = c.evaluateAndApply(auto(.dark), system: .dark, now: t0 + 2000)   // user goes back to dark
        #expect(!c.overridden)
    }

    @Test func pausedHoldsEvenWhenOutOfSync() {
        var c = controller()
        c.paused = true
        #expect(c.evaluateAndApply(auto(.dark), system: .light, now: t0).target == nil)
        c.paused = false
        #expect(c.evaluateAndApply(auto(.dark), system: .light, now: t0 + 1).target == .dark)
    }

    @Test func configCanBeSwappedForHotReload() {
        var c = controller()
        _ = c.evaluateAndApply(auto(.dark), system: .light, now: t0)         // dark
        var newConfig = c.config
        newConfig.minSecondsBetweenSwitches = 0
        c.config = newConfig
        #expect(c.evaluateAndApply(auto(.light), system: .dark, now: t0 + 100).target == .light)
    }

    @Test func failedSwitchIsRetriedAndIsNotMistakenForAManualChange() {
        var c = controller()
        // The switch to dark is requested but the apply fails (e.g. permission denied):
        // didApply is never called and the system stays light.
        #expect(c.evaluate(auto(.dark), system: .light, now: t0).target == .dark)
        #expect(c.evaluate(auto(.dark), system: .light, now: t0 + 10).target == .dark)  // retried
        #expect(!c.overridden)
    }

    @Test func failedSwitchDoesNotStartTheMinimumTimeClock() {
        var c = controller()
        _ = c.evaluate(auto(.dark), system: .light, now: t0)     // failed, not applied
        #expect(c.evaluate(auto(.dark), system: .light, now: t0 + 10).target == .dark)
    }

    @Test func appliedSwitchIsRemembered() {
        var c = controller()
        _ = c.evaluate(auto(.dark), system: .light, now: t0)
        c.didApply(.dark, at: t0)
        #expect(c.evaluate(auto(.dark), system: .dark, now: t0 + 10).target == nil)
        #expect(!c.overridden)
        // and the minimum time between switches now counts from t0
        #expect(c.evaluate(auto(.light), system: .dark, now: t0 + 10).target == nil)
    }
}
