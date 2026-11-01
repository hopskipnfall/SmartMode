import Foundation

private struct OpenMeteoSearchResponse: Decodable {
    struct Result: Decodable {
        let name: String
        let latitude: Double?
        let longitude: Double?
        let admin1: String?
        let country: String?
    }
    // Absent entirely when nothing matches.
    let results: [Result]?
}

/// "City, Region, Country", leaving out empty parts and any part that repeats the one before it.
public func placeLabel(_ parts: [String?]) -> String {
    var out: [String] = []
    for part in parts {
        guard let part, !part.isEmpty, part != out.last else { continue }
        out.append(part)
    }
    return out.joined(separator: ", ")
}

/// Parses an Open-Meteo geocoding search response. Results without coordinates are skipped.
public func parsePlaces(_ data: Data) throws -> [Place] {
    let response = try JSONDecoder().decode(OpenMeteoSearchResponse.self, from: data)
    return (response.results ?? []).compactMap { r in
        guard let lat = r.latitude, let lon = r.longitude else { return nil }
        return Place(label: placeLabel([r.name, r.admin1, r.country]), latitude: lat, longitude: lon)
    }
}

/// Reads typed coordinates such as "35.67, 139.66" (comma, semicolon or space separated).
public func parseCoordinates(_ text: String) -> Place? {
    let parts = text.split(whereSeparator: { ", ;".contains($0) }).map(String.init)
    guard parts.count == 2, let lat = Double(parts[0]), let lon = Double(parts[1]),
          (-90...90).contains(lat), (-180...180).contains(lon) else { return nil }
    return Place(label: String(format: "%.4f, %.4f", lat, lon), latitude: lat, longitude: lon)
}

/// Combines result lists in priority order, dropping places within `nearKm` of an earlier one.
public func mergePlaces(_ lists: [[Place]], nearKm: Double = 25, limit: Int = 8) -> [Place] {
    var merged: [Place] = []
    for place in lists.joined() {
        if merged.contains(where: { distanceKm($0, place) < nearKm }) { continue }
        merged.append(place)
        if merged.count == limit { break }
    }
    return merged
}

private func distanceKm(_ a: Place, _ b: Place) -> Double {
    func rad(_ d: Double) -> Double { d * .pi / 180 }
    let dLat = rad(b.latitude - a.latitude)
    let dLon = rad(b.longitude - a.longitude)
    let h = sin(dLat / 2) * sin(dLat / 2)
        + cos(rad(a.latitude)) * cos(rad(b.latitude)) * sin(dLon / 2) * sin(dLon / 2)
    return 6371 * 2 * asin(min(1, sqrt(h)))
}
