import Foundation

/// A semantic version such as 1.2.3 or 0.1.0-beta.1, ordered by the semver rules:
/// numbers compare numerically, and a release is newer than its own prereleases.
public struct SemanticVersion: Equatable, Comparable {
    let core: [Int]            // major, minor, patch
    let prerelease: [String]   // empty for a release

    /// Accepts a leading "v", missing minor/patch parts, and ignores "+build" metadata.
    public init?(_ text: String) {
        var s = text.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("v") || s.hasPrefix("V") { s.removeFirst() }
        if let plus = s.firstIndex(of: "+") { s = String(s[..<plus]) }

        let parts = s.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        guard let numbers = parts.first else { return nil }
        let pieces = numbers.split(separator: ".", omittingEmptySubsequences: false)
        let parsed = pieces.map { Int($0) }
        guard (1...3).contains(pieces.count), parsed.allSatisfy({ ($0 ?? -1) >= 0 }) else { return nil }
        core = parsed.map { $0! } + Array(repeating: 0, count: 3 - pieces.count)

        if parts.count > 1 {
            let identifiers = parts[1].split(separator: ".", omittingEmptySubsequences: false).map(String.init)
            guard !identifiers.isEmpty, identifiers.allSatisfy({ !$0.isEmpty }) else { return nil }
            prerelease = identifiers
        } else {
            prerelease = []
        }
    }

    public static func < (a: SemanticVersion, b: SemanticVersion) -> Bool {
        if a.core != b.core { return a.core.lexicographicallyPrecedes(b.core) }
        switch (a.prerelease.isEmpty, b.prerelease.isEmpty) {
        case (true, _): return false       // a release is never older than a prerelease of itself
        case (false, true): return true
        case (false, false): return comparePrerelease(a.prerelease, b.prerelease) < 0
        }
    }

    private static func comparePrerelease(_ a: [String], _ b: [String]) -> Int {
        for (x, y) in zip(a, b) {
            if x == y { continue }
            switch (Int(x), Int(y)) {
            case let (m?, n?): return m < n ? -1 : 1
            case (_?, nil): return -1      // numeric identifiers sort before text ones
            case (nil, _?): return 1
            default: return x < y ? -1 : 1
            }
        }
        return a.count == b.count ? 0 : (a.count < b.count ? -1 : 1)
    }
}
