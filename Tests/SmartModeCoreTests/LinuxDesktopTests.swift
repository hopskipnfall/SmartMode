import Testing
@testable import SmartModeCore

struct LinuxDesktopTests {
    @Test func detectsCinnamonAndFallsBackToGnome() {
        #expect(LinuxDesktop.detect(currentDesktop: "X-Cinnamon") == .cinnamon)
        #expect(LinuxDesktop.detect(currentDesktop: "ubuntu:GNOME") == .gnome)
        #expect(LinuxDesktop.detect(currentDesktop: nil) == .gnome)
    }

    @Test func mintThemesPairUp() {
        #expect(cinnamonTheme(from: "Mint-Y", dark: true) == "Mint-Y-Dark")
        #expect(cinnamonTheme(from: "Mint-Y-Dark", dark: false) == "Mint-Y")
        #expect(cinnamonTheme(from: "Mint-Y-Aqua", dark: true) == "Mint-Y-Dark-Aqua")
        #expect(cinnamonTheme(from: "Mint-Y-Dark-Aqua", dark: false) == "Mint-Y-Aqua")
        #expect(cinnamonTheme(from: "Mint-Y-Dark-Aqua", dark: true) == "Mint-Y-Dark-Aqua")
        #expect(cinnamonTheme(from: nil, dark: true) == "Mint-Y-Dark")
        #expect(cinnamonTheme(from: "Adwaita", dark: true) == "Adwaita-Dark")
    }

    @Test func cinnamonChangesThemesAndColorScheme() {
        let changes = gsettingsChanges(for: .cinnamon, appearance: .dark, currentGtkTheme: "Mint-Y")
        #expect(changes == [
            ["org.gnome.desktop.interface", "color-scheme", "prefer-dark"],
            ["org.cinnamon.desktop.interface", "gtk-theme", "Mint-Y-Dark"],
            ["org.cinnamon.theme", "name", "Mint-Y-Dark"],
        ])
        #expect(gsettingsChanges(for: .gnome, appearance: .light, currentGtkTheme: nil)
                == [["org.gnome.desktop.interface", "color-scheme", "default"]])
    }

    @Test func readsAppearanceBack() {
        #expect(currentAppearance(for: .cinnamon, colorScheme: "'default'\n", gtkTheme: "'Mint-Y-Dark'\n") == .dark)
        #expect(currentAppearance(for: .cinnamon, colorScheme: "'default'", gtkTheme: "'Mint-Y'") == .light)
        #expect(currentAppearance(for: .gnome, colorScheme: "'prefer-dark'", gtkTheme: nil) == .dark)
    }

    @Test func illuminanceUsesInputThenRawWithScale() {
        #expect(illuminanceLux(input: "123.5\n", raw: "9", scale: "2", offset: nil) == 123.5)
        #expect(illuminanceLux(input: nil, raw: "100", scale: "0.5", offset: "10") == 55)
        #expect(illuminanceLux(input: nil, raw: "42", scale: nil, offset: nil) == 42)
        #expect(illuminanceLux(input: nil, raw: nil, scale: "1", offset: nil) == nil)
    }

    @Test func lidState() {
        #expect(lidIsClosed(acpiState: "state:      closed\n"))
        #expect(!lidIsClosed(acpiState: "state:      open\n"))
    }

    @Test func autostartEntryRunsTheExecutable() {
        #expect(autostartEntry(executablePath: "/usr/local/bin/smart-mode").contains("Exec=/usr/local/bin/smart-mode"))
    }
}
