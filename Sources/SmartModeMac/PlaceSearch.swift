import Foundation
import SmartModeCore

struct SearchOutcome {
    var places: [Place]
    /// True when the lookup itself failed (e.g. offline), as opposed to simply finding nothing.
    var failed: Bool
}

/// Looks a place up by name with Open-Meteo's geocoding API (English). Typed coordinates
/// skip the lookup entirely.
enum PlaceSearch {
    static func search(_ rawQuery: String) async -> SearchOutcome {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return SearchOutcome(places: [], failed: false) }
        if let typed = parseCoordinates(query) { return SearchOutcome(places: [typed], failed: false) }

        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "8"),
            URLQueryItem(name: "language", value: "en"),
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
