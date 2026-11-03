import Foundation
import Yams

public enum ConfigError: Error, Equatable {
    case invalid(String)
}

/// Where the user is. All three values may be empty; `name` is only ever displayed.
public struct LocationConfig: Codable, Equatable {
    public var name: String?
    public var latitude: Double?
    public var longitude: Double?

    public init(name: String? = nil, latitude: Double? = nil, longitude: Double? = nil) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }

    enum CodingKeys: String, CodingKey {
        case name = "locationName"
        case latitude, longitude
    }

    public init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        latitude = try c.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)
    }
}

public struct NightConfig: Codable, Equatable {
    /// It's night when the cloud-adjusted sun elevation is below this many degrees.
    public var sunBelowDegrees = 5.0
    /// 100% cloud cover counts as the sun being this many degrees lower.
    public var cloudDarkeningDegrees = 13.0

    public init() {}
    enum CodingKeys: String, CodingKey { case sunBelowDegrees, cloudDarkeningDegrees }
    public init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sunBelowDegrees = try c.decodeIfPresent(Double.self, forKey: .sunBelowDegrees) ?? sunBelowDegrees
        cloudDarkeningDegrees = try c.decodeIfPresent(Double.self, forKey: .cloudDarkeningDegrees) ?? cloudDarkeningDegrees
    }
}

public struct RoomConfig: Codable, Equatable {
    /// In daytime, go dark at or below this much light.
    public var darkBelowLux = 72.0
    /// In daytime, go back to light at or above this much light.
    public var lightAboveLux = 92.0
    /// Multiplier from raw sensor units to lux. Leave at 1 unless the sensor reads off.
    public var luxScale = 1.0

    public init() {}
    enum CodingKeys: String, CodingKey { case darkBelowLux, lightAboveLux, luxScale }
    public init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        darkBelowLux = try c.decodeIfPresent(Double.self, forKey: .darkBelowLux) ?? darkBelowLux
        lightAboveLux = try c.decodeIfPresent(Double.self, forKey: .lightAboveLux) ?? lightAboveLux
        luxScale = try c.decodeIfPresent(Double.self, forKey: .luxScale) ?? luxScale
    }
}

public struct Config: Codable, Equatable {
    public var location = LocationConfig()
    public var night = NightConfig()
    public var room = RoomConfig()
    public var minSecondsBetweenSwitches = 60.0

    /// Everything defaulted; the arguments are a convenience for building a config with a location.
    public init(latitude: Double? = nil, longitude: Double? = nil, locationName: String? = nil) {
        location = LocationConfig(name: locationName, latitude: latitude, longitude: longitude)
    }

    enum CodingKeys: String, CodingKey {
        case location, night, room, minSecondsBetweenSwitches
    }

    public init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        location = try c.decodeIfPresent(LocationConfig.self, forKey: .location) ?? location
        night = try c.decodeIfPresent(NightConfig.self, forKey: .night) ?? night
        room = try c.decodeIfPresent(RoomConfig.self, forKey: .room) ?? room
        minSecondsBetweenSwitches = try c.decodeIfPresent(Double.self, forKey: .minSecondsBetweenSwitches) ?? minSecondsBetweenSwitches
    }

    /// All defaults, with no location (it comes from the menu).
    public static let example = Config()

    /// The file written on first launch: every setting at its default, with a comment where
    /// the name alone doesn't explain it.
    public static let defaultFileText = """
    # Where you are, used to work out where the sun is. Set it from the menu ("Set location…")
    # or fill in latitude and longitude by hand. locationName is only shown in the menu.
    location:
      locationName:
      latitude:
      longitude:

    night:
      # Dark mode is enabled when the sun, adjusted for cloud, is lower than this many degrees.
      # 5 = about half an hour before sunset on a clear day, 0 = sunset/sunrise,
      # -6 = end of civil twilight. At night it's always dark.
      sunBelowDegrees: 5
      # Cloud makes it darker: 100% cloud cover counts as the sun being this many degrees lower.
      cloudDarkeningDegrees: 13

    room:
      # In daytime the light sensor can switch to dark when the room is dim.
      darkBelowLux: 72     # go dark at or below this much light...
      lightAboveLux: 92    # ...and back to light at or above this (dim room ~5-30, normal indoor ~100-300)
      luxScale: 1          # only if the sensor's units are off

    minSecondsBetweenSwitches: 60
    """

    /// Parses YAML, then validates.
    public static func parse(_ data: Data) throws -> Config {
        let config = try YAMLDecoder().decode(Config.self, from: data)
        try config.validate()
        return config
    }

    func validate() throws {
        guard (location.latitude == nil) == (location.longitude == nil) else {
            throw ConfigError.invalid("set both location.latitude and location.longitude, or neither")
        }
        if let lat = location.latitude, !(-90...90).contains(lat) {
            throw ConfigError.invalid("location.latitude must be within -90...90")
        }
        if let lon = location.longitude, !(-180...180).contains(lon) {
            throw ConfigError.invalid("location.longitude must be within -180...180")
        }
        guard room.darkBelowLux < room.lightAboveLux else {
            throw ConfigError.invalid("room.darkBelowLux must be less than room.lightAboveLux")
        }
        guard room.luxScale > 0 else { throw ConfigError.invalid("room.luxScale must be > 0") }
        guard night.cloudDarkeningDegrees >= 0 else { throw ConfigError.invalid("night.cloudDarkeningDegrees must be >= 0") }
        guard minSecondsBetweenSwitches >= 0 else { throw ConfigError.invalid("minSecondsBetweenSwitches must be >= 0") }
    }
}
