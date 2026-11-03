import Testing
@testable import SmartModeCore

struct SemanticVersionTests {
    private func v(_ s: String) -> SemanticVersion { SemanticVersion(s)! }

    @Test func parsesPlainAndPrefixedVersions() {
        #expect(SemanticVersion("1.0.0") != nil)
        #expect(SemanticVersion("v1.0.0") == SemanticVersion("1.0.0"))
        #expect(SemanticVersion("V2.3.4") == SemanticVersion("2.3.4"))
    }

    @Test func shortVersionsAreFilledOut() {
        #expect(SemanticVersion("1.2") == SemanticVersion("1.2.0"))
        #expect(SemanticVersion("3") == SemanticVersion("3.0.0"))
    }

    @Test func parsesPrereleaseAndIgnoresBuildMetadata() {
        #expect(SemanticVersion("0.1.0-beta.1") != nil)
        #expect(SemanticVersion("1.0.0+abc123") == SemanticVersion("1.0.0"))
    }

    @Test func rejectsGarbage() {
        for text in ["", "abc", "1.x.0", "1.0.0.0", "1.0.0-", "-1.0.0", "1..0"] {
            #expect(SemanticVersion(text) == nil, "for \(text)")
        }
    }

    @Test func ordersByNumbersNotText() {
        #expect(v("1.0.1") > v("1.0.0"))
        #expect(v("1.10.0") > v("1.9.0"))
        #expect(v("2.0.0") > v("1.99.99"))
    }

    @Test func aReleaseBeatsItsPrereleases() {
        #expect(v("1.0.0") > v("1.0.0-beta.1"))
        #expect(v("1.0.0") > v("1.0.0-rc.1"))
    }

    @Test func prereleasesAreOrderedByIdentifier() {
        #expect(v("1.0.0-beta.2") > v("1.0.0-beta.1"))
        #expect(v("1.0.0-beta.10") > v("1.0.0-beta.2"))   // numeric, not textual
        #expect(v("1.0.0-rc.1") > v("1.0.0-beta.9"))
        #expect(v("1.0.0-beta") < v("1.0.0-beta.1"))       // fewer identifiers sorts first
    }

    @Test func aBetaOfTheNextVersionBeatsTheCurrentRelease() {
        #expect(v("1.1.0-beta.1") > v("1.0.0"))
    }

    @Test func equalVersionsAreNotOrdered() {
        #expect(!(v("1.0.0") < v("1.0.0")))
        #expect(!(v("1.0.0") > v("1.0.0")))
    }
}
