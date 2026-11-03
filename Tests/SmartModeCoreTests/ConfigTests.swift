import Foundation
import Testing
@testable import SmartModeCore

struct ConfigTests {
    private func data(_ s: String) -> Data { s.data(using: .utf8)! }

    @Test func minimalConfigGetsDefaults() throws {
        let c = try Config.parse(data("latitude: 35.67\nlongitude: 139.66\n"))
        #expect(c.latitude == 35.67)
        #expect(c.longitude == 139.66)
        #expect(c.night.sunBelowDegrees == 5)
        #expect(c.night.cloudDarkeningDegrees == 13)
        #expect(c.room.darkBelowLux == 72)
        #expect(c.room.lightAboveLux == 92)
        #expect(c.room.luxScale == 1)
        #expect(c.minSecondsBetweenSwitches == 60)
    }

    @Test func wholeNumbersDecodeAsDoubles() throws {
        let c = try Config.parse(data("latitude: 0\nlongitude: -120\nnight:\n  sunBelowDegrees: -6\n"))
        #expect(c.latitude == 0)
        #expect(c.longitude == -120)
        #expect(c.night.sunBelowDegrees == -6)
    }

    @Test func partialOverrideOfNestedSection() throws {
        let c = try Config.parse(data("latitude: 0\nlongitude: 0\nroom:\n  darkBelowLux: 40\n"))
        #expect(c.room.darkBelowLux == 40)
        #expect(c.room.lightAboveLux == 92) // untouched default
    }

    @Test func acceptsCommentsAndInlineComments() throws {
        let text = """
        # where I live
        latitude: 35.67
        longitude: 139.66   # east
        room:
          darkBelowLux: 50  # dim
        """
        let c = try Config.parse(data(text))
        #expect(c.room.darkBelowLux == 50)
    }

    @Test func legacyKeysAreIgnoredAndDefaultsApply() throws {
        // A config from the old weighted-score version still loads: location carries over.
        let legacy = "latitude: 35.67\nlongitude: 139.66\ndarkThreshold: 0.6\nlux:\n  weight: 6\n  darkLux: 60\n"
        let c = try Config.parse(data(legacy))
        #expect(c.latitude == 35.67)
        #expect(c.room.darkBelowLux == 72)
    }

    @Test func rejectsInvertedLuxThresholds() {
        #expect(throws: (any Error).self) {
            try Config.parse(data("latitude: 0\nlongitude: 0\nroom:\n  darkBelowLux: 100\n  lightAboveLux: 50\n"))
        }
    }

    @Test func rejectsOutOfRangeLatitude() {
        #expect(throws: (any Error).self) {
            try Config.parse(data("latitude: 123\nlongitude: 0\n"))
        }
    }

    @Test func locationIsOptional() throws {
        let c = try Config.parse(data("night:\n  sunBelowDegrees: -4\n"))
        #expect(c.latitude == nil)
        #expect(c.longitude == nil)
    }

    @Test func rejectsOnlyOneCoordinate() {
        #expect(throws: (any Error).self) { try Config.parse(data("latitude: 35.67\n")) }
        #expect(throws: (any Error).self) { try Config.parse(data("longitude: 139.66\n")) }
    }

    @Test func rejectsBadIndentation() {
        #expect(throws: (any Error).self) {
            try Config.parse(data("latitude: 0\nlongitude: 0\nroom:\n  darkBelowLux: 40\n lightAboveLux: 90\n"))
        }
    }

    @Test func rejectsANonNumberWhereANumberBelongs() {
        #expect(throws: (any Error).self) {
            try Config.parse(data("latitude: north\nlongitude: 0\n"))
        }
    }

    @Test func defaultFileParsesToTheExampleConfig() throws {
        #expect(try Config.parse(data(Config.defaultFileText)) == Config.example)
    }

    @Test func defaultFileDoesNotSetACoordinateOverride() throws {
        let c = try Config.parse(data(Config.defaultFileText))
        #expect(c.latitude == nil)
        #expect(c.longitude == nil)
    }

    @Test func defaultFileHasNoCommentOnTheObviousSetting() {
        #expect(!Config.defaultFileText.contains("Don't switch more often"))
    }
}
