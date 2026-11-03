import Testing
@testable import SmartModeCore

struct WindowsThemeTests {
    @Test func zeroMeansDarkAndAnythingElseIsLight() {
        #expect(windowsAppearance(appsUseLightTheme: 0) == .dark)
        #expect(windowsAppearance(appsUseLightTheme: 1) == .light)
        #expect(windowsAppearance(appsUseLightTheme: nil) == .light)
    }

    @Test func themeValueRoundTrips() {
        for appearance in [Appearance.light, .dark] {
            #expect(windowsAppearance(appsUseLightTheme: windowsThemeValue(for: appearance)) == appearance)
        }
    }

    @Test func runCommandQuotesThePath() {
        #expect(windowsRunCommand(executablePath: "C:\\Program Files\\SmartMode\\SmartModeWindows.exe")
                == "\"C:\\Program Files\\SmartMode\\SmartModeWindows.exe\"")
    }
}
