import Foundation
import SmartModeCore

/// Remembers the place chosen from the menu, in the app's own preferences so the user's
/// hand-edited config file is never rewritten.
enum LocationStore {
    private static let key = "chosenPlace"

    static func load() -> Place? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Place.self, from: data)
    }

    static func save(_ place: Place) {
        guard let data = try? JSONEncoder().encode(place) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
