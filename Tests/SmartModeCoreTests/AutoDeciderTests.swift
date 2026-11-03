import Testing
@testable import SmartModeCore

struct AutoDeciderTests {
    private func decider() -> AutoDecider {
        AutoDecider(config: Config(latitude: 0, longitude: 0)) // night < 5°, cloud darkens by 13°, dark <= 72 lux, light >= 92 lux
    }

    @Test func nightIsDarkEvenInABrightRoom() {
        var d = decider()
        let r = d.decide(Readings(lux: 348, sunElevation: -24))
        #expect(r?.mode == .dark)
        #expect(r?.reason.contains("night") == true)
    }

    @Test func nightIsDarkWithoutASensorReading() {
        var d = decider()
        #expect(d.decide(Readings(sunElevation: -24))?.mode == .dark)
    }

    @Test func brightRoomInDaytimeIsLight() {
        var d = decider()
        #expect(d.decide(Readings(lux: 300, sunElevation: 30))?.mode == .light)
    }

    @Test func darkRoomInDaytimeOverridesToDark() {
        var d = decider()
        let r = d.decide(Readings(lux: 50, sunElevation: 30))
        #expect(r?.mode == .dark)
        #expect(r?.reason.contains("daytime") == true)
    }

    @Test func roomHysteresisHoldsBetweenThresholds() {
        var d = decider()
        #expect(d.decide(Readings(lux: 50, sunElevation: 30))?.mode == .dark)
        #expect(d.decide(Readings(lux: 80, sunElevation: 30))?.mode == .dark)   // between 72 and 92
        #expect(d.decide(Readings(lux: 95, sunElevation: 30))?.mode == .light)
        #expect(d.decide(Readings(lux: 80, sunElevation: 30))?.mode == .light)  // still between
        #expect(d.decide(Readings(lux: 70, sunElevation: 30))?.mode == .dark)
    }

    @Test func daytimeWithoutSensorIsLight() {
        var d = decider()
        _ = d.decide(Readings(lux: 50, sunElevation: 30))                       // room dark
        #expect(d.decide(Readings(sunElevation: 30))?.mode == .light)           // lid closed
    }

    @Test func cloudCoverBringsNightEarlier() {
        var clear = decider()
        #expect(clear.decide(Readings(lux: 300, sunElevation: 6))?.mode == .light)
        var cloudy = decider()
        // 100% cloud darkens by 13°: 6° -> -7° effective, which is night.
        #expect(cloudy.decide(Readings(lux: 300, sunElevation: 6, cloudCoverPercent: 100))?.mode == .dark)
    }

    @Test func nightBoundaryHasHysteresis() {
        var d = decider()
        #expect(d.decide(Readings(lux: 300, sunElevation: 4.5))?.mode == .dark)    // night begins (< 5°)
        #expect(d.decide(Readings(lux: 300, sunElevation: 5.5))?.mode == .dark)    // still night (within 1°)
        #expect(d.decide(Readings(lux: 300, sunElevation: 6.1))?.mode == .light)   // day again
    }

    @Test func darkRoomAtDawnStaysDark() {
        var d = decider()
        _ = d.decide(Readings(lux: 20, sunElevation: -10))
        #expect(d.decide(Readings(lux: 20, sunElevation: 10))?.mode == .dark)
    }

    @Test func luxScaleMultipliesTheRawReading() {
        var config = Config(latitude: 0, longitude: 0)
        config.room.luxScale = 10
        var d = AutoDecider(config: config)
        #expect(d.decide(Readings(lux: 5, sunElevation: 30))?.mode == .dark)   // 5 * 10 = 50 lux
    }

    @Test func noSunPositionMeansNoDecision() {
        var d = decider()
        #expect(d.decide(Readings(lux: 5)) == nil)
    }

    @Test func summariesDescribeTheInputs() {
        var d = decider()
        let r = d.decide(Readings(lux: 62.9, sunElevation: 19.4, cloudCoverPercent: 75))!
        #expect(r.sunSummary.contains("19.4"))
        #expect(r.sunSummary.contains("75%"))
        #expect(r.roomSummary.contains("62.9"))
        #expect(d.decide(Readings(sunElevation: 19.4))!.roomSummary.contains("no sensor"))
    }
}
