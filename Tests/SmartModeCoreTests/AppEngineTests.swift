import Foundation
import Testing
@testable import SmartModeCore

private final class FakeServices: PlatformServices {
    var appearance = Appearance.light
    var lux: Double?
    var applied: [Appearance] = []
    var fetched: [URL] = []

    func currentAppearance() -> Appearance { appearance }
    func apply(_ appearance: Appearance) throws {
        applied.append(appearance)
        self.appearance = appearance
    }
    func readLux(now: Date) -> Double? { lux }
    func fetch(_ url: URL, _ completion: @escaping (Data?) -> Void) {
        fetched.append(url)
        completion(nil)
    }
}

private func tempConfig() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("smartmode-\(UUID().uuidString)/config.yaml")
}

struct AppEngineTests {
    @Test func withoutALocationItDoesNothing() {
        let services = FakeServices()
        let engine = AppEngine(services: services, configURL: tempConfig())
        engine.tick(now: Date(timeIntervalSince1970: 1_767_279_600))
        #expect(engine.needsLocation)
        #expect(services.applied.isEmpty)
        #expect(engine.lines.contains { $0.contains("doing nothing until a location is set") })
    }

    @Test func choosingAPlaceSavesItAndSwitchesToDarkAtNight() {
        let services = FakeServices()
        let url = tempConfig()
        let engine = AppEngine(services: services, configURL: url)
        // Midnight in Tokyo.
        let midnight = Date(timeIntervalSince1970: 1_767_279_600)
        engine.tick(now: midnight)
        engine.choose(Place(label: "Tokyo, Japan", latitude: 35.6895, longitude: 139.69171))
        engine.tick(now: midnight)
        #expect(engine.locationLabel == "Tokyo, Japan")
        #expect((try? String(contentsOf: url, encoding: .utf8))?.contains("Tokyo, Japan") == true)
        #expect(services.applied == [.dark])
        #expect(services.fetched.first?.host == "api.open-meteo.com")
    }

    @Test func pausingStopsSwitching() {
        let services = FakeServices()
        let engine = AppEngine(services: services, configURL: tempConfig())
        engine.paused = true
        engine.choose(Place(label: "Tokyo, Japan", latitude: 35.6895, longitude: 139.69171))
        engine.tick(now: Date(timeIntervalSince1970: 1_767_279_600))
        #expect(services.applied.isEmpty)
    }
}
