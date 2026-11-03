import Foundation
import SmartModeCore

struct AvailableUpdate: Equatable {
    let version: String
    let url: URL
}

/// Asks GitHub for the latest published release at most once a day (retrying an hour after a
/// failure) and remembers the answer, so the "new version" item survives restarts without
/// asking again. The only thing sent is the request itself.
@MainActor
final class UpdateChecker {
    static let releasesPage = URL(string: "https://github.com/hopskipnfall/SmartMode/releases/latest")!
    private static let apiURL = URL(string: "https://api.github.com/repos/hopskipnfall/SmartMode/releases/latest")!

    private enum Key {
        static let lastSuccess = "update.lastSuccess"
        static let lastAttempt = "update.lastAttempt"
        static let latestTag = "update.latestTag"
        static let latestURL = "update.latestURL"
    }

    private let defaults = UserDefaults.standard
    private var inFlight = false

    /// nil when not running from an app bundle (e.g. `swift run`), which disables checking.
    let currentVersion: String? = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String

    /// The remembered latest release, if it is newer than the running version.
    var available: AvailableUpdate? {
        guard let current = currentVersion,
              let tag = defaults.string(forKey: Key.latestTag),
              isUpdateAvailable(current: current, latestTag: tag) else { return nil }
        let url = defaults.string(forKey: Key.latestURL).flatMap(URL.init(string:)) ?? Self.releasesPage
        return AvailableUpdate(version: tag.hasPrefix("v") ? String(tag.dropFirst()) : tag, url: url)
    }

    /// Starts a check if one is due; `onFinish` runs once it has completed, successfully or not.
    func checkIfDue(now: Date, onFinish: @escaping () -> Void) {
        guard !inFlight, let current = currentVersion else { return }
        let lastSuccess = defaults.object(forKey: Key.lastSuccess) as? Date
        let lastAttempt = defaults.object(forKey: Key.lastAttempt) as? Date
        guard isUpdateCheckDue(now: now, lastSuccess: lastSuccess, lastAttempt: lastAttempt) else { return }

        defaults.set(now, forKey: Key.lastAttempt)
        inFlight = true
        var request = URLRequest(url: Self.apiURL, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("SmartMode/\(current)", forHTTPHeaderField: "User-Agent")

        Task { @MainActor in
            defer {
                inFlight = false
                onFinish()
            }
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                switch (response as? HTTPURLResponse)?.statusCode {
                case 200:
                    let release = try parseLatestRelease(data)
                    defaults.set(release.tag, forKey: Key.latestTag)
                    defaults.set(release.url?.absoluteString, forKey: Key.latestURL)
                    defaults.set(Date(), forKey: Key.lastSuccess)
                case 404:
                    // No published (non-prerelease) release exists yet: nothing to offer, and not an error.
                    defaults.removeObject(forKey: Key.latestTag)
                    defaults.removeObject(forKey: Key.latestURL)
                    defaults.set(Date(), forKey: Key.lastSuccess)
                default:
                    break   // rate limited or a server error: try again in an hour
                }
            } catch {
                // Offline or unparseable: try again in an hour.
            }
        }
    }
}
