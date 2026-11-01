import CoreLocation
import Foundation
import SmartModeCore

struct SearchOutcome {
    var places: [Place]
    /// True when every source failed (e.g. offline), as opposed to simply finding nothing.
    var failed: Bool
}

/// Looks a place up by name using two sources at once: Apple's geocoder (handles native-script
/// queries like 東京 and labels results in the system language) and Open-Meteo (returns several
/// candidates for ambiguous names). Typed coordinates skip the lookup entirely.
enum PlaceSearch {
    static func search(_ rawQuery: String) async -> SearchOutcome {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return SearchOutcome(places: [], failed: false) }
        if let typed = parseCoordinates(query) { return SearchOutcome(places: [typed], failed: false) }

        async let apple = appleSearch(query)
        async let meteo = openMeteoSearch(query)
        let (a, m) = await (apple, meteo)
        return SearchOutcome(places: mergePlaces([a.places, m.places]), failed: a.failed && m.failed)
    }

    private static func appleSearch(_ query: String) async -> SearchOutcome {
        do {
            let marks = try await CLGeocoder().geocodeAddressString(query)
            let places = marks.compactMap { mark -> Place? in
                guard let c = mark.location?.coordinate else { return nil }
                return Place(label: placeLabel([mark.locality ?? mark.name, mark.administrativeArea, mark.country]),
                             latitude: c.latitude, longitude: c.longitude)
            }
            return SearchOutcome(places: places, failed: false)
        } catch let error as CLError where error.code == .geocodeFoundNoResult {
            return SearchOutcome(places: [], failed: false)
        } catch {
            return SearchOutcome(places: [], failed: true)
        }
    }

    private static func openMeteoSearch(_ query: String) async -> SearchOutcome {
        let language = Locale.preferredLanguages.first
            .flatMap { Locale(identifier: $0).language.languageCode?.identifier } ?? "en"
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "8"),
            URLQueryItem(name: "language", value: language),
            URLQueryItem(name: "format", value: "json"),
        ]
        do {
            let (data, _) = try await URLSession.shared.data(from: components.url!)
            return SearchOutcome(places: try parsePlaces(data), failed: false)
        } catch {
            return SearchOutcome(places: [], failed: true)
        }
    }
}
