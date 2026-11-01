import Foundation
import Yams

public enum ConfigError: Error, Equatable {
    case invalid(String)
}

public struct NightConfig: Codable, Equatable {
    /// It's night when the cloud-adjusted sun elevation is below this many degrees.
    public var sunBelowDegrees = -4.0
    /// 100% cloud cover counts as the sun being this many degrees lower.
    public var cloudDarkeningDegrees = 8.0

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
    /// Optional exact coordinates. When set they override a place chosen from the menu.
    public var latitude: Double?
    public var longitude: Double?
    public var night = NightConfig()
    public var room = RoomConfig()
    public var minSecondsBetweenSwitches = 60.0

    public init(latitude: Double? = nil, longitude: Double? = nil) {
        self.latitude = latitude
        self.longitude = longitude
    }

    enum CodingKeys: String, CodingKey {
        case latitude, longitude, night, room, minSecondsBetweenSwitches
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            latitude: try c.decodeIfPresent(Double.self, forKey: .latitude),
            longitude: try c.decodeIfPresent(Double.self, forKey: .longitude)
        )
        night = try c.decodeIfPresent(NightConfig.self, forKey: .night) ?? night
        room = try c.decodeIfPresent(RoomConfig.self, forKey: .room) ?? room
        minSecondsBetweenSwitches = try c.decodeIfPresent(Double.self, forKey: .minSecondsBetweenSwitches) ?? minSecondsBetweenSwitches
    }

    /// All defaults, with no location (it comes from the menu).
    public static let example = Config()

    /// The file written on first launch: every setting at its default, with a comment where
    /// the name alone doesn't explain it.
    public static let defaultFileText = """
    # Your location is set from the menu ("Set location…"). To use exact coordinates
    # instead, which override the menu's choice, uncomment these two lines:
    # latitude: 35.6895
    # longitude: 139.6917

    night:
      # It's night when the sun is lower than this many degrees below the horizon.
      # 0 = sunset/sunrise, -6 = end of civil twilight. At night it's always dark.
      sunBelowDegrees: -4
      # Cloud makes it feel darker: 100% cloud counts as the sun being this many degrees lower.
      cloudDarkeningDegrees: 8

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
        guard (latitude == nil) == (longitude == nil) else {
            throw ConfigError.invalid("set both latitude and longitude, or neither")
        }
        if let latitude, !(-90...90).contains(latitude) { throw ConfigError.invalid("latitude must be within -90...90") }
        if let longitude, !(-180...180).contains(longitude) { throw ConfigError.invalid("longitude must be within -180...180") }
        guard room.darkBelowLux < room.lightAboveLux else {
            throw ConfigError.invalid("room.darkBelowLux must be less than room.lightAboveLux")
        }
        guard room.luxScale > 0 else { throw ConfigError.invalid("room.luxScale must be > 0") }
        guard night.cloudDarkeningDegrees >= 0 else { throw ConfigError.invalid("night.cloudDarkeningDegrees must be >= 0") }
        guard minSecondsBetweenSwitches >= 0 else { throw ConfigError.invalid("minSecondsBetweenSwitches must be >= 0") }
    }
}
