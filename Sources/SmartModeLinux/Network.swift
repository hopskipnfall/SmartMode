import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import SmartModeCore

/// GTK owns the main thread and never drains the Dispatch main queue, so networking uses plain
/// completion handlers and hops back to the GTK thread with `onMain`.
enum Network {
    static func get(_ url: URL, _ completion: @escaping (Data?) -> Void) {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("SmartMode", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { data, response, _ in
            let ok = (response as? HTTPURLResponse).map { (200..<300).contains($0.statusCode) } ?? false
            onMain { completion(ok ? data : nil) }
        }.resume()
    }

    /// Typed coordinates skip the lookup; otherwise Open-Meteo's geocoding API (English).
    static func searchPlaces(_ rawQuery: String, _ completion: @escaping (_ places: [Place], _ failed: Bool) -> Void) {
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
        get(components.url!) { data in
            guard let data, let places = try? parsePlaces(data) else { return completion([], true) }
            completion(places, false)
        }
    }
}

/// Cloud cover from Open-Meteo, refreshed at most every 15 minutes. Main thread only.
final class WeatherProvider {
    private let pollInterval: TimeInterval = 15 * 60
    private let maxAge: TimeInterval = 3 * 60 * 60
    private var cached: (value: Double, fetchedAt: Date)?
    private var lastAttempt: Date?
    private var inFlight = false
    private var coordinates: (latitude: Double, longitude: Double)?

    func cloudCover(now: Date) -> Double? {
        guard let cached, now.timeIntervalSince(cached.fetchedAt) <= maxAge else { return nil }
        return cached.value
    }

    func refreshIfNeeded(latitude: Double, longitude: Double, now: Date) {
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
        Network.get(url) { [self] data in
            // Ignore a response for a location the user has since moved away from.
            guard coordinates?.latitude == latitude, coordinates?.longitude == longitude else { return }
            inFlight = false
            if let data, let value = try? parseCloudCover(data) { cached = (value, Date()) }
        }
    }
}
