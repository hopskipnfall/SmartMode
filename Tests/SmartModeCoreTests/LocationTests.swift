import Testing
@testable import SmartModeCore

struct LocationTests {
    @Test func configLocationResolvesWithItsName() {
        let loc = resolveLocation(config: Config(latitude: 35.6895, longitude: 139.69171, locationName: "Tokyo, Japan"))
        #expect(loc?.latitude == 35.6895)
        #expect(loc?.longitude == 139.69171)
        #expect(loc?.label == "Tokyo, Japan")
    }

    @Test func withoutANameTheLabelIsTheCoordinates() {
        #expect(resolveLocation(config: Config(latitude: 10, longitude: 20))?.label == "10.0000, 20.0000")
    }

    @Test func anEmptyNameFallsBackToTheCoordinates() {
        let loc = resolveLocation(config: Config(latitude: 10, longitude: 20, locationName: ""))
        #expect(loc?.label == "10.0000, 20.0000")
    }

    @Test func noCoordinatesMeansNoLocation() {
        #expect(resolveLocation(config: Config()) == nil)
        #expect(resolveLocation(config: Config(locationName: "Tokyo")) == nil)
    }
}
