import Foundation
import Testing
@testable import SmartModeCore

struct ConfigTests {
    private func data(_ s: String) -> Data { s.data(using: .utf8)! }

    @Test func minimalConfigGetsDefaults() throws {
        let c = try Config.parse(data(#"{"latitude": 35.67, "longitude": 139.66}"#))
        #expect(c.latitude == 35.67)
        #expect(c.longitude == 139.66)
        #expect(c.night.sunBelowDegrees == -4)
        #expect(c.night.cloudDarkeningDegrees == 8)
        #expect(c.room.darkBelowLux == 72)
        #expect(c.room.lightAboveLux == 92)
        #expect(c.room.luxScale == 1)
        #expect(c.minSecondsBetweenSwitches == 60)
    }

    @Test func partialOverrideOfNestedSection() throws {
        let c = try Config.parse(data(#"{"latitude": 0, "longitude": 0, "room": {"darkBelowLux": 40}}"#))
        #expect(c.room.darkBelowLux == 40)
        #expect(c.room.lightAboveLux == 92) // untouched default
    }

    @Test func acceptsCommentsAndTrailingCommas() throws {
        let text = """
        {
          // where I live
          "latitude": 35.67,
          "longitude": 139.66, /* east */
          "room": { "darkBelowLux": 50, },
        }
        """
        let c = try Config.parse(data(text))
        #expect(c.room.darkBelowLux == 50)
    }

    @Test func legacyKeysAreIgnoredAndDefaultsApply() throws {
        // A config from the old weighted-score version still loads: location carries over.
        let legacy = #"{"latitude": 35.67, "longitude": 139.66, "darkThreshold": 0.6, "lux": {"weight": 6, "darkLux": 60}}"#
        let c = try Config.parse(data(legacy))
        #expect(c.latitude == 35.67)
        #expect(c.room.darkBelowLux == 72)
    }

    @Test func rejectsInvertedLuxThresholds() {
        #expect(throws: (any Error).self) {
            try Config.parse(data(#"{"latitude": 0, "longitude": 0, "room": {"darkBelowLux": 100, "lightAboveLux": 50}}"#))
        }
    }

    @Test func rejectsOutOfRangeLatitude() {
        #expect(throws: (any Error).self) {
            try Config.parse(data(#"{"latitude": 123, "longitude": 0}"#))
        }
    }

    @Test func rejectsMalformedJSON() {
        #expect(throws: (any Error).self) { try Config.parse(data("{nope")) }
    }

    @Test func defaultFileParsesToTheExampleConfig() throws {
        #expect(try Config.parse(data(Config.defaultFileText)) == Config.example)
    }
}
