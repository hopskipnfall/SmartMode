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
