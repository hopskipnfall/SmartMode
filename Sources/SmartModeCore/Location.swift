import Foundation

/// A place the user picked: a human label plus coordinates.
public struct Place: Codable, Equatable, Identifiable {
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

/// The coordinates the app actually uses, and where they came from.
public struct Location: Equatable {
    public let latitude: Double
    public let longitude: Double
    public let label: String
    public let setInConfig: Bool
}

/// Coordinates written in the config file override a place picked from the menu;
/// with neither, there's no location and the app can't place the sun.
public func resolveLocation(config: Config, saved: Place?) -> Location? {
    if let lat = config.latitude, let lon = config.longitude {
        return Location(latitude: lat, longitude: lon,
                        label: String(format: "%.4f, %.4f", lat, lon), setInConfig: true)
    }
    if let saved {
        return Location(latitude: saved.latitude, longitude: saved.longitude,
                        label: saved.label, setInConfig: false)
    }
    return nil
}
