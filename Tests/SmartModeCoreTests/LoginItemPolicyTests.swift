import Testing
@testable import SmartModeCore

struct LoginItemPolicyTests {
    private let home = "/Users/ness"

    private func shouldEnable(applied: Bool = false, path: String) -> Bool {
        shouldEnableLoginItemByDefault(alreadyApplied: applied, bundlePath: path, homeDirectory: home)
    }

    @Test func enablesOnFirstLaunchFromApplications() {
        #expect(shouldEnable(path: "/Applications/SmartMode.app"))
    }

    @Test func enablesFromTheUsersOwnApplicationsFolder() {
        #expect(shouldEnable(path: "/Users/ness/Applications/SmartMode.app"))
    }

    @Test func neverAppliesTwice() {
        #expect(!shouldEnable(applied: true, path: "/Applications/SmartMode.app"))
    }

    @Test func skipsCopiesRunFromElsewhere() {
        #expect(!shouldEnable(path: "/Users/ness/workspaces/smart-mode/SmartMode.app"))
        #expect(!shouldEnable(path: "/Users/ness/Downloads/SmartMode.app"))
        #expect(!shouldEnable(path: "/Volumes/Backup/Applications/SmartMode.app"))
    }

    @Test func skipsAQuarantinedCopyRunningFromATranslocationFolder() {
        #expect(!shouldEnable(path: "/private/var/folders/ab/cd/T/AppTranslocation/1234/d/SmartMode.app"))
    }

    @Test func aFolderMerelyNamedLikeApplicationsDoesNotCount() {
        #expect(!shouldEnable(path: "/Applications-old/SmartMode.app"))
        #expect(!shouldEnable(path: "/Users/ness/ApplicationsBackup/SmartMode.app"))
    }

    @Test func aSkippedLaunchLeavesTheChoiceOpenForLater() {
        // Not installed yet: nothing is recorded, so once it is moved to /Applications it can apply.
        #expect(!shouldEnable(applied: false, path: "/Users/ness/Downloads/SmartMode.app"))
        #expect(shouldEnable(applied: false, path: "/Applications/SmartMode.app"))
    }
}
