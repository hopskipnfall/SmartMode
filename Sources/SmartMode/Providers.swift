import Foundation
import SensorShim
import SmartModeCore

final class SensorProvider {
    private let fieldIndex: Int32
    private var window = RollingWindow(duration: 60)

    /// Field 7 tracks ambient light on this machine (see the note in SmartModeProbe/main.swift).
    init(fieldIndex: Int32 = 7) {
        self.fieldIndex = fieldIndex
    }

    func read(now: Date) -> Double? {
        // With the lid closed (clamshell) the sensor sees nothing; don't let that vote "dark".
        guard lid_is_closed() == 0 else { return nil }
        let raw = sensor_read_field(fieldIndex)
        if raw.isFinite { window.add(raw, at: now) }
        return window.median(at: now)
    }
}

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

    /// Call from the main actor. Fetches at most every 15 minutes; failures keep serving the cache.
    @MainActor
    func refreshIfNeeded(latitude: Double, longitude: Double, now: Date) {
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
        Task { @MainActor in
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let value = try parseCloudCover(data)
                // Ignore a response for a location the user has since moved away from.
                guard self.coordinates?.latitude == latitude, self.coordinates?.longitude == longitude else { return }
                self.cached = (value, Date())
                self.inFlight = false
            } catch {
                // Keep serving the cache until maxAge; the menu shows cloud cover as n/a after that.
                if self.coordinates?.latitude == latitude, self.coordinates?.longitude == longitude {
                    self.inFlight = false
                }
            }
        }
    }
}
