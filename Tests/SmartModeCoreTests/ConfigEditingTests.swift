import Foundation
import Testing
@testable import SmartModeCore

struct ConfigEditingTests {
    private let tokyo = Place(label: "Tokyo, Japan", latitude: 35.6895, longitude: 139.69171)

    private func parse(_ text: String) throws -> Config { try Config.parse(text.data(using: .utf8)!) }

    @Test func fillsTheEmptyLocationSectionOfTheDefaultFile() throws {
        let edited = configText(Config.defaultFileText, settingLocationTo: tokyo)
        let c = try parse(edited)
        #expect(c.location.name == "Tokyo, Japan")
        #expect(c.location.latitude == 35.6895)
        #expect(c.location.longitude == 139.6917)
    }

    @Test func leavesEverythingOutsideTheLocationLinesUntouched() {
        let edited = configText(Config.defaultFileText, settingLocationTo: tokyo)
        let before = Config.defaultFileText.components(separatedBy: "\n")
        let after = edited.components(separatedBy: "\n")
        #expect(before.count == after.count)
        let changed = zip(before, after).filter { $0 != $1 }.map(\.1)
        #expect(changed.count == 3)   // exactly locationName, latitude, longitude
        #expect(after.contains("night:"))
        #expect(after.contains("  sunBelowDegrees: 5"))
        #expect(after.contains("minSecondsBetweenSwitches: 60"))
    }

    @Test func replacesExistingValuesAndKeepsComments() throws {
        let text = """
        # my notes
        location:
          locationName: "Old Place"
          latitude: 1.0
          longitude: 2.0

        # room settings
        room:
          darkBelowLux: 50
        """
        let edited = configText(text, settingLocationTo: tokyo)
        let c = try parse(edited)
        #expect(c.location.name == "Tokyo, Japan")
        #expect(c.location.latitude == 35.6895)
        #expect(c.room.darkBelowLux == 50)
        #expect(edited.contains("# my notes"))
        #expect(edited.contains("# room settings"))
        #expect(!edited.contains("Old Place"))
    }

    @Test func addsMissingKeysInsideAnExistingSection() throws {
        let text = "location:\n  latitude: 1\n  longitude: 2\nroom:\n  darkBelowLux: 50\n"
        let c = try parse(configText(text, settingLocationTo: tokyo))
        #expect(c.location.name == "Tokyo, Japan")
        #expect(c.location.latitude == 35.6895)
        #expect(c.room.darkBelowLux == 50)
    }

    @Test func insertsASectionWhenThereIsNone() throws {
        let text = "night:\n  sunBelowDegrees: 3\n"
        let edited = configText(text, settingLocationTo: tokyo)
        let c = try parse(edited)
        #expect(c.location.latitude == 35.6895)
        #expect(c.night.sunBelowDegrees == 3)
    }

    @Test func worksOnAnEmptyFile() throws {
        let c = try parse(configText("", settingLocationTo: tokyo))
        #expect(c.location.latitude == 35.6895)
    }

    @Test func ignoresCommentedOutKeysInsideTheSection() throws {
        let text = "location:\n  # latitude: 99\n  latitude:\n  longitude:\n"
        let edited = configText(text, settingLocationTo: tokyo)
        #expect(edited.contains("  # latitude: 99"))
        #expect(try parse(edited).location.latitude == 35.6895)
    }

    @Test func namesWithYAMLSpecialCharactersRoundTrip() throws {
        for name in ["Springfield: IL", "Portland # Oregon", #"The "Big" Apple"#, #"back\slash"#, "O'Hare, Chicago"] {
            let place = Place(label: name, latitude: 1.5, longitude: 2.5)
            let c = try parse(configText(Config.defaultFileText, settingLocationTo: place))
            #expect(c.location.name == name, "for \(name)")
        }
    }

    @Test func typedCoordinatesLeaveTheNameEmpty() throws {
        let typed = parseCoordinates("35.67, 139.66")!
        let c = try parse(configText(Config.defaultFileText, settingLocationTo: typed))
        #expect(c.location.name == nil)
        #expect(c.location.latitude == 35.67)
        #expect(c.location.longitude == 139.66)
    }

    @Test func keepsNegativeAndPreciseValues() throws {
        let sydney = Place(label: "Sydney, Australia", latitude: -33.8688, longitude: 151.2093)
        let c = try parse(configText(Config.defaultFileText, settingLocationTo: sydney))
        #expect(c.location.latitude == -33.8688)
        #expect(c.location.longitude == 151.2093)
    }

    @Test func applyingTheSamePlaceTwiceChangesNothing() {
        let once = configText(Config.defaultFileText, settingLocationTo: tokyo)
        #expect(configText(once, settingLocationTo: tokyo) == once)
    }

    @Test func aSecondPlaceReplacesTheFirst() throws {
        let osaka = Place(label: "Osaka, Japan", latitude: 34.6937, longitude: 135.5022)
        let once = configText(Config.defaultFileText, settingLocationTo: tokyo)
        let c = try parse(configText(once, settingLocationTo: osaka))
        #expect(c.location.name == "Osaka, Japan")
        #expect(c.location.latitude == 34.6937)
    }
}
