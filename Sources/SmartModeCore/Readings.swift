public struct Readings: Equatable {
    public var lux: Double?
    public var sunElevation: Double?
    public var cloudCoverPercent: Double?

    public init(lux: Double? = nil, sunElevation: Double? = nil, cloudCoverPercent: Double? = nil) {
        self.lux = lux
        self.sunElevation = sunElevation
        self.cloudCoverPercent = cloudCoverPercent
    }
}
