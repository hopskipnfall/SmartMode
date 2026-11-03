import Foundation
import Testing
@testable import SmartModeCore

struct IssueReportTests {
    private func items(_ url: URL) -> [String: String] {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        return Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    }

    @Test func pointsAtTheNewIssuePageOfTheRepository() {
        let url = bugReportURL(version: "1.0.0", macOS: "macOS 27.2")
        #expect(url.absoluteString.hasPrefix("https://github.com/hopskipnfall/SmartMode/issues/new?"))
    }

    @Test func prefillsTheTemplateVersionAndMacOS() {
        let q = items(bugReportURL(version: "1.0.0", macOS: "macOS 27.2.1"))
        #expect(q["template"] == "bug_report.yml")
        #expect(q["version"] == "1.0.0")
        #expect(q["macos"] == "macOS 27.2.1")
    }

    @Test func sendsNothingElse() {
        let q = items(bugReportURL(version: "1.0.0", macOS: "macOS 27.2"))
        #expect(Set(q.keys) == ["template", "version", "macos"])
    }

    @Test func specialCharactersSurviveEncoding() {
        let weird = "1.0.0-beta.1 (build a&b=c#d)"
        let url = bugReportURL(version: weird, macOS: "macOS 27")
        #expect(items(url)["version"] == weird)
        #expect(!url.absoluteString.contains(" "))
    }
}
