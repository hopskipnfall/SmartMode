import Foundation
import Testing
@testable import SmartModeCore

struct GeocodingTests {
    private func data(_ s: String) -> Data { s.data(using: .utf8)! }

    @Test func parsesResultsInOrder() throws {
        let json = """
        {"results":[
          {"id":1,"name":"Tokyo","latitude":35.6895,"longitude":139.69171,"country":"Japan","admin1":"Tokyo"},
          {"id":2,"name":"Tokyo","latitude":-8.4,"longitude":147.15,"country":"Papua New Guinea","admin1":"Central Province"}
        ],"generationtime_ms":0.3}
        """
        let places = try parsePlaces(data(json))
        #expect(places.count == 2)
        #expect(places[0].latitude == 35.6895)
        #expect(places[0].longitude == 139.69171)
        #expect(places[1].label == "Tokyo, Central Province, Papua New Guinea")
    }

    @Test func labelDropsRegionWhenItRepeatsTheName() throws {
        let json = #"{"results":[{"name":"Tokyo","latitude":35.6,"longitude":139.7,"country":"Japan","admin1":"Tokyo"}]}"#
        #expect(try parsePlaces(data(json))[0].label == "Tokyo, Japan")
    }

    @Test func labelCopesWithMissingRegionAndCountry() throws {
        let json = #"{"results":[{"name":"Somewhere","latitude":1,"longitude":2}]}"#
        #expect(try parsePlaces(data(json))[0].label == "Somewhere")
    }

    @Test func noMatchesHasNoResultsKeyAndGivesAnEmptyList() throws {
        #expect(try parsePlaces(data(#"{"generationtime_ms":0.05}"#)).isEmpty)
    }

    @Test func skipsResultsWithoutCoordinates() throws {
        let json = #"{"results":[{"name":"Broken"},{"name":"Ok","latitude":1,"longitude":2}]}"#
        let places = try parsePlaces(data(json))
        #expect(places.map(\.label) == ["Ok"])
    }

    @Test func malformedJSONThrows() {
        #expect(throws: (any Error).self) { try parsePlaces(data("not json")) }
    }
}

struct CoordinateParsingTests {
    @Test func parsesCommonSeparators() {
        for text in ["35.67, 139.66", "35.67,139.66", "35.67 139.66", "  35.67 ;  139.66 "] {
            let p = parseCoordinates(text)
            #expect(p?.latitude == 35.67, "for \(text)")
            #expect(p?.longitude == 139.66, "for \(text)")
        }
    }

    @Test func parsesNegativeValues() {
        let p = parseCoordinates("-33.87, 151.21")
        #expect(p?.latitude == -33.87)
        let q = parseCoordinates("40.7, -74.0")
        #expect(q?.longitude == -74.0)
    }

    @Test func labelShowsFourDecimals() {
        #expect(parseCoordinates("35.67, 139.66")?.label == "35.6700, 139.6600")
    }

    @Test func rejectsNonCoordinatesAndOutOfRange() {
        #expect(parseCoordinates("Tokyo") == nil)
        #expect(parseCoordinates("35.67") == nil)
        #expect(parseCoordinates("35.67, 139.66, 5") == nil)
        #expect(parseCoordinates("91, 0") == nil)
        #expect(parseCoordinates("0, 181") == nil)
    }
}
