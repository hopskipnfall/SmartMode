import Foundation

/// Cloud cover from Open-Meteo, refreshed at most every 15 minutes; failures keep serving the
/// cache. The fetch is injected so each platform can deliver the response on its own UI thread.
/// Call everything from that one thread.
public final class WeatherProvider {
    public typealias Fetch = (URL, @escaping (Data?) -> Void) -> Void

    private let fetch: Fetch
    private let pollInterval: TimeInterval = 15 * 60
    private let maxAge: TimeInterval = 3 * 60 * 60
    private var cached: (value: Double, fetchedAt: Date)?
    private var lastAttempt: Date?
    private var inFlight = false
    private var coordinates: (latitude: Double, longitude: Double)?

    public init(fetch: @escaping Fetch) {
        self.fetch = fetch
    }

    public func cloudCover(now: Date) -> Double? {
        guard let cached, now.timeIntervalSince(cached.fetchedAt) <= maxAge else { return nil }
        return cached.value
    }

    public func refreshIfNeeded(latitude: Double, longitude: Double, now: Date) {
        // A different location invalidates the cache and any fetch for the old one.
        if coordinates?.latitude != latitude || coordinates?.longitude != longitude {
            coordinates = (latitude, longitude)
            cached = nil
            lastAttempt = nil
            inFlight = false
        }
        if inFlight { return }
        if let lastAttempt, now.timeIntervalSince(lastAttempt) < pollInterval { return }
        lastAttempt = now
        inFlight = true
        let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current=cloud_cover")!
        fetch(url) { [self] data in
            // Ignore a response for a location the user has since moved away from.
            guard coordinates?.latitude == latitude, coordinates?.longitude == longitude else { return }
            inFlight = false
            if let data, let value = try? parseCloudCover(data) { cached = (value, Date()) }
        }
    }
}

/// Looks a place up by name with Open-Meteo's geocoding API (English). Typed coordinates skip the lookup.
public func searchPlaces(_ rawQuery: String, fetch: WeatherProvider.Fetch,
                         completion: @escaping (_ places: [Place], _ failed: Bool) -> Void) {
    let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return completion([], false) }
    if let typed = parseCoordinates(query) { return completion([typed], false) }
    var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
    components.queryItems = [
        URLQueryItem(name: "name", value: query),
        URLQueryItem(name: "count", value: "8"),
        URLQueryItem(name: "language", value: "en"),
        URLQueryItem(name: "format", value: "json"),
    ]
    fetch(components.url!) { data in
        guard let data, let places = try? parsePlaces(data) else { return completion([], true) }
        completion(places, false)
    }
}
