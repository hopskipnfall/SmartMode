import Foundation
import Testing
@testable import SmartModeCore

struct LocationTests {
    private let tokyo = Place(label: "Tokyo, Japan", latitude: 35.6895, longitude: 139.69171)

    @Test func configCoordinatesOverrideASavedPlace() {
        let loc = resolveLocation(config: Config(latitude: 10, longitude: 20), saved: tokyo)
        #expect(loc?.latitude == 10)
        #expect(loc?.longitude == 20)
        #expect(loc?.label == "10.0000, 20.0000")
        #expect(loc?.setInConfig == true)
    }

    @Test func savedPlaceIsUsedWhenTheConfigHasNoCoordinates() {
        let loc = resolveLocation(config: Config(), saved: tokyo)
        #expect(loc?.latitude == 35.6895)
        #expect(loc?.label == "Tokyo, Japan")
        #expect(loc?.setInConfig == false)
    }

    @Test func noLocationAnywhereIsNil() {
        #expect(resolveLocation(config: Config(), saved: nil) == nil)
    }

    @Test func placeSurvivesAJSONRoundTrip() throws {
        let data = try JSONEncoder().encode(tokyo)
        #expect(try JSONDecoder().decode(Place.self, from: data) == tokyo)
    }
}
