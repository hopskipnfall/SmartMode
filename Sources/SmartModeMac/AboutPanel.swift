import AppKit

/// The standard macOS About panel. The version and copyright come from the app's Info.plist
/// (written by scripts/build-app.sh from the VERSION file); the credits add the links.
@MainActor
enum AboutPanel {
    static let repositoryURL = URL(string: "https://github.com/hopskipnfall/SmartMode")!
    static let authorURL = URL(string: "https://github.com/hopskipnfall")!
    static let licenseURL = URL(string: "https://www.apache.org/licenses/LICENSE-2.0")!

    static func show() {
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits()])
        NSApp.activate(ignoringOtherApps: true)
    }

    private static func credits() -> NSAttributedString {
        let body = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let base: [NSAttributedString.Key: Any] = [
            .font: body, .paragraphStyle: paragraph, .foregroundColor: NSColor.labelColor,
        ]

        let text = NSMutableAttributedString(
            string: "Switches between light and dark mode using the sun and your room's brightness.\n\n",
            attributes: base)

        func link(_ title: String, _ url: URL) -> NSAttributedString {
            var attributes = base
            attributes[.link] = url
            return NSAttributedString(string: title, attributes: attributes)
        }
        func plain(_ s: String) -> NSAttributedString { NSAttributedString(string: s, attributes: base) }

        text.append(plain("By "))
        text.append(link("Jonn Spencer", authorURL))
        text.append(plain("\n"))
        text.append(link("github.com/hopskipnfall/SmartMode", repositoryURL))
        text.append(plain("\nLicensed under the "))
        text.append(link("Apache License 2.0", licenseURL))
        return text
    }
}
