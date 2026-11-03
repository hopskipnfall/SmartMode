import Foundation
import Testing
@testable import SmartModeCore

struct ConfigTests {
    private func data(_ s: String) -> Data { s.data(using: .utf8)! }
    private let tokyo = "location:\n  latitude: 35.67\n  longitude: 139.66\n"

    @Test func minimalConfigGetsDefaults() throws {
        let c = try Config.parse(data(tokyo))
        #expect(c.location.latitude == 35.67)
        #expect(c.location.longitude == 139.66)
        #expect(c.night.sunBelowDegrees == 5)
        #expect(c.night.cloudDarkeningDegrees == 13)
        #expect(c.room.darkBelowLux == 72)
        #expect(c.room.lightAboveLux == 92)
        #expect(c.room.luxScale == 1)
        #expect(c.minSecondsBetweenSwitches == 60)
        #expect(c.checkForUpdates == true)
    }

    @Test func updateChecksCanBeTurnedOff() throws {
        #expect(try Config.parse(data("checkForUpdates: false\n")).checkForUpdates == false)
    }

    @Test func locationNameIsDisplayOnly() throws {
        let c = try Config.parse(data("location:\n  locationName: Tokyo, Japan\n  latitude: 35.67\n  longitude: 139.66\n"))
        #expect(c.location.name == "Tokyo, Japan")
    }

    @Test func emptyLocationValuesAreNil() throws {
        let c = try Config.parse(data("location:\n  locationName:\n  latitude:\n  longitude:\n"))
        #expect(c.location.name == nil)
        #expect(c.location.latitude == nil)
        #expect(c.location.longitude == nil)
    }

    @Test func locationIsOptional() throws {
        let c = try Config.parse(data("night:\n  sunBelowDegrees: 3\n"))
        #expect(c.location.latitude == nil)
        #expect(c.night.sunBelowDegrees == 3)
    }

    @Test func wholeNumbersDecodeAsDoubles() throws {
        let c = try Config.parse(data("location:\n  latitude: 0\n  longitude: -120\nnight:\n  sunBelowDegrees: -6\n"))
        #expect(c.location.latitude == 0)
        #expect(c.location.longitude == -120)
        #expect(c.night.sunBelowDegrees == -6)
    }

    @Test func partialOverrideOfNestedSection() throws {
        let c = try Config.parse(data("room:\n  darkBelowLux: 40\n"))
        #expect(c.room.darkBelowLux == 40)
        #expect(c.room.lightAboveLux == 92) // untouched default
    }

    @Test func acceptsCommentsAndInlineComments() throws {
        let text = """
        # where I live
        location:
          latitude: 35.67   # north
          longitude: 139.66 # east
        room:
          darkBelowLux: 50  # dim
        """
        let c = try Config.parse(data(text))
        #expect(c.location.longitude == 139.66)
        #expect(c.room.darkBelowLux == 50)
    }

    @Test func topLevelCoordinatesFromTheFirstBetaAreNotRead() throws {
        let c = try Config.parse(data("latitude: 35.67\nlongitude: 139.66\n"))
        #expect(c.location.latitude == nil)
        #expect(c.location.longitude == nil)
    }

    @Test func legacyScoreKeysAreIgnoredAndDefaultsApply() throws {
        let legacy = tokyo + "darkThreshold: 0.6\nlux:\n  weight: 6\n  darkLux: 60\n"
        let c = try Config.parse(data(legacy))
        #expect(c.location.latitude == 35.67)
        #expect(c.room.darkBelowLux == 72)
    }

    @Test func rejectsInvertedLuxThresholds() {
        #expect(throws: (any Error).self) {
            try Config.parse(data("room:\n  darkBelowLux: 100\n  lightAboveLux: 50\n"))
        }
    }

    @Test func rejectsOutOfRangeCoordinates() {
        #expect(throws: (any Error).self) {
            try Config.parse(data("location:\n  latitude: 123\n  longitude: 0\n"))
        }
        #expect(throws: (any Error).self) {
            try Config.parse(data("location:\n  latitude: 0\n  longitude: 181\n"))
        }
    }

    @Test func rejectsOnlyOneCoordinate() {
        #expect(throws: (any Error).self) { try Config.parse(data("location:\n  latitude: 35.67\n")) }
        #expect(throws: (any Error).self) { try Config.parse(data("location:\n  longitude: 139.66\n")) }
    }

    @Test func rejectsBadIndentation() {
        #expect(throws: (any Error).self) {
            try Config.parse(data("room:\n  darkBelowLux: 40\n lightAboveLux: 90\n"))
        }
    }

    @Test func rejectsANonNumberWhereANumberBelongs() {
        #expect(throws: (any Error).self) {
            try Config.parse(data("location:\n  latitude: north\n  longitude: 0\n"))
        }
    }

    @Test func defaultFileParsesToTheExampleConfig() throws {
        #expect(try Config.parse(data(Config.defaultFileText)) == Config.example)
    }

    @Test func defaultFileHasAnEmptyLocationSection() throws {
        let c = try Config.parse(data(Config.defaultFileText))
        #expect(c.location == LocationConfig())
        #expect(Config.defaultFileText.contains("location:\n  locationName:\n  latitude:\n  longitude:"))
    }

    @Test func defaultFileHasNoCommentOnTheObviousSetting() {
        #expect(!Config.defaultFileText.contains("Don't switch more often"))
    }
}
