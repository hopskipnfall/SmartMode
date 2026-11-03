import Foundation

/// A place found by a search: a human label plus coordinates.
public struct Place: Equatable, Identifiable {
    public let label: String
    public let latitude: Double
    public let longitude: Double

    public init(label: String, latitude: Double, longitude: Double) {
        self.label = label
        self.latitude = latitude
        self.longitude = longitude
    }

    public var id: String { "\(label)|\(latitude)|\(longitude)" }
}

/// The coordinates the app actually uses, with a label for the menu.
public struct Location: Equatable {
    public let latitude: Double
    public let longitude: Double
    public let label: String
}

/// The configured location, or nil when none is set (the app can't place the sun without one).
public func resolveLocation(config: Config) -> Location? {
    guard let lat = config.location.latitude, let lon = config.location.longitude else { return nil }
    let name = config.location.name.flatMap { $0.isEmpty ? nil : $0 }
    return Location(latitude: lat, longitude: lon, label: name ?? String(format: "%.4f, %.4f", lat, lon))
}
