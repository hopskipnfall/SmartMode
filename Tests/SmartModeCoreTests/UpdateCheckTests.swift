import Foundation
import Testing
@testable import SmartModeCore

struct UpdateCheckTests {
    private func data(_ s: String) -> Data { s.data(using: .utf8)! }
    private let t0 = Date(timeIntervalSince1970: 2_000_000_000)

    // MARK: parsing the GitHub response

    @Test func parsesTheLatestReleaseResponse() throws {
        let json = """
        {"url":"https://api.github.com/x","tag_name":"v1.2.0","name":"SmartMode 1.2.0",
         "html_url":"https://github.com/hopskipnfall/SmartMode/releases/tag/v1.2.0","draft":false}
        """
        let release = try parseLatestRelease(data(json))
        #expect(release.tag == "v1.2.0")
        #expect(release.url == URL(string: "https://github.com/hopskipnfall/SmartMode/releases/tag/v1.2.0"))
    }

    @Test func aMissingPageURLIsFine() throws {
        #expect(try parseLatestRelease(data(#"{"tag_name":"v1.0.0"}"#)).url == nil)
    }

    @Test func aResponseWithoutATagThrows() {
        #expect(throws: (any Error).self) { try parseLatestRelease(data(#"{"message":"Not Found"}"#)) }
        #expect(throws: (any Error).self) { try parseLatestRelease(data("not json")) }
    }

    // MARK: is there an update?

    @Test func aNewerReleaseIsAnUpdate() {
        #expect(isUpdateAvailable(current: "0.1.0-beta.1", latestTag: "v1.0.0"))
        #expect(isUpdateAvailable(current: "1.0.0", latestTag: "v1.0.1"))
    }

    @Test func theSameOrAnOlderReleaseIsNot() {
        #expect(!isUpdateAvailable(current: "1.0.0", latestTag: "v1.0.0"))
        #expect(!isUpdateAvailable(current: "1.0.1", latestTag: "v1.0.0"))
    }

    @Test func unreadableVersionsNeverClaimAnUpdate() {
        #expect(!isUpdateAvailable(current: "dev", latestTag: "v1.0.0"))
        #expect(!isUpdateAvailable(current: "1.0.0", latestTag: "latest"))
    }

    // MARK: when to check

    @Test func neverCheckedIsDue() {
        #expect(isUpdateCheckDue(now: t0, lastSuccess: nil, lastAttempt: nil))
    }

    @Test func aRecentSuccessIsNotDue() {
        let hourAgo = t0.addingTimeInterval(-3_600)
        #expect(!isUpdateCheckDue(now: t0, lastSuccess: hourAgo, lastAttempt: hourAgo))
        let almost = t0.addingTimeInterval(-86_000)
        #expect(!isUpdateCheckDue(now: t0, lastSuccess: almost, lastAttempt: almost))
    }

    @Test func aDayAfterASuccessIsDue() {
        let dayAgo = t0.addingTimeInterval(-86_400)
        #expect(isUpdateCheckDue(now: t0, lastSuccess: dayAgo, lastAttempt: dayAgo))
    }

    @Test func aRecentFailureWaitsAnHour() {
        let thirtyMinutes = t0.addingTimeInterval(-1_800)
        #expect(!isUpdateCheckDue(now: t0, lastSuccess: nil, lastAttempt: thirtyMinutes))
        let twoHours = t0.addingTimeInterval(-7_200)
        #expect(isUpdateCheckDue(now: t0, lastSuccess: nil, lastAttempt: twoHours))
    }

    @Test func aFailureAfterAnOldSuccessStillWaitsAnHour() {
        let twoDaysAgo = t0.addingTimeInterval(-172_800)
        let tenMinutes = t0.addingTimeInterval(-600)
        #expect(!isUpdateCheckDue(now: t0, lastSuccess: twoDaysAgo, lastAttempt: tenMinutes))
    }

    @Test func aClockSetBackwardsDoesNotStallChecks() {
        // A last-success time in the future (clock changed) shouldn't block checking forever.
        let future = t0.addingTimeInterval(500_000)
        #expect(isUpdateCheckDue(now: t0, lastSuccess: future, lastAttempt: future))
    }
}
