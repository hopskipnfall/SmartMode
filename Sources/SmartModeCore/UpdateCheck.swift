import Foundation

public struct LatestRelease: Equatable {
    public let tag: String
    public let url: URL?
}

private struct GitHubReleaseResponse: Decodable {
    let tag_name: String
    let html_url: String?
}

/// Reads GitHub's "latest release" response (https://api.github.com/repos/<owner>/<repo>/releases/latest).
public func parseLatestRelease(_ data: Data) throws -> LatestRelease {
    let response = try JSONDecoder().decode(GitHubReleaseResponse.self, from: data)
    return LatestRelease(tag: response.tag_name, url: response.html_url.flatMap(URL.init(string:)))
}

/// True only when the latest release is strictly newer than the running version. A build that is
/// ahead of the latest release, or a version string we can't read, never claims an update.
public func isUpdateAvailable(current: String, latestTag: String) -> Bool {
    guard let current = SemanticVersion(current), let latest = SemanticVersion(latestTag) else { return false }
    return latest > current
}

/// Whether to ask GitHub again: a day after the last success, but after a failed attempt only
/// retry once an hour has passed. A check at login often runs before the network is up, and that
/// shouldn't silence the check for a day.
public func isUpdateCheckDue(now: Date, lastSuccess: Date?, lastAttempt: Date?,
                             interval: TimeInterval = 86_400, retryAfterFailure: TimeInterval = 3_600) -> Bool {
    func elapsed(since date: Date?) -> TimeInterval {
        guard let date else { return .infinity }
        let seconds = now.timeIntervalSince(date)
        return seconds < 0 ? .infinity : seconds     // a clock set backwards must not stall checks
    }
    return elapsed(since: lastSuccess) >= interval && elapsed(since: lastAttempt) >= retryAfterFailure
}
