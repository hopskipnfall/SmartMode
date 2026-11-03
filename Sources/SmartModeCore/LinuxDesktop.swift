import Foundation

/// Which desktop's settings decide light vs dark. Cinnamon (Linux Mint) switches whole themes;
/// GNOME and most others have a single colour-scheme switch.
public enum LinuxDesktop: Equatable {
    case cinnamon
    case gnome

    /// `XDG_CURRENT_DESKTOP` is a colon-separated list, e.g. "X-Cinnamon" or "ubuntu:GNOME".
    public static func detect(currentDesktop: String?) -> LinuxDesktop {
        let parts = (currentDesktop ?? "").lowercased().split(separator: ":")
        return parts.contains { $0.contains("cinnamon") } ? .cinnamon : .gnome
    }
}

/// The Mint-Y themes come in pairs: "Mint-Y-Aqua" / "Mint-Y-Dark-Aqua". Other themes get a
/// "-Dark" suffix added or removed; with nothing to go on, the plain Mint-Y pair is used.
public func cinnamonTheme(from current: String?, dark: Bool) -> String {
    guard let current, !current.isEmpty else { return dark ? "Mint-Y-Dark" : "Mint-Y" }
    if current.hasPrefix("Mint-Y") {
        let accent = current.dropFirst("Mint-Y".count)
            .replacingOccurrences(of: "-Dark", with: "")
        return "Mint-Y" + (dark ? "-Dark" : "") + accent
    }
    let base = current.replacingOccurrences(of: "-Dark", with: "").replacingOccurrences(of: "-dark", with: "")
    return dark ? base + "-Dark" : base
}

/// The `gsettings set` arguments (schema, key, value) that switch the desktop to `appearance`.
/// `currentGtkTheme` is read from `org.cinnamon.desktop.interface gtk-theme` (Cinnamon only).
public func gsettingsChanges(for desktop: LinuxDesktop, appearance: Appearance,
                             currentGtkTheme: String?) -> [[String]] {
    let dark = appearance == .dark
    // libadwaita and portal-aware apps follow this on every desktop.
    var changes = [["org.gnome.desktop.interface", "color-scheme", dark ? "prefer-dark" : "default"]]
    if desktop == .cinnamon {
        let theme = cinnamonTheme(from: currentGtkTheme, dark: dark)
        changes.append(["org.cinnamon.desktop.interface", "gtk-theme", theme])
        changes.append(["org.cinnamon.theme", "name", theme])
    }
    return changes
}

/// Reads the current appearance back from `gsettings get` output (values come quoted: 'Mint-Y-Dark').
public func currentAppearance(for desktop: LinuxDesktop, colorScheme: String?, gtkTheme: String?) -> Appearance {
    func unquote(_ s: String?) -> String { (s ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "' \n")) }
    if desktop == .cinnamon, unquote(gtkTheme).lowercased().contains("dark") { return .dark }
    return unquote(colorScheme) == "prefer-dark" ? .dark : .light
}

/// A `.desktop` file for ~/.config/autostart so the app starts with the session.
public func autostartEntry(executablePath: String) -> String {
    """
    [Desktop Entry]
    Type=Application
    Name=SmartMode
    Comment=Switch between light and dark mode from the sun and room brightness
    Exec=\(executablePath)
    X-GNOME-Autostart-enabled=true
    Terminal=false
    """
}

/// Turns the contents of an IIO `in_illuminance_*` set of files into lux. Prefers the
/// processed `_input` value; otherwise `(raw + offset) * scale`, where scale and offset default to 1 and 0.
public func illuminanceLux(input: String?, raw: String?, scale: String?, offset: String?) -> Double? {
    func number(_ s: String?) -> Double? { s.flatMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) } }
    if let value = number(input) { return value }
    guard let raw = number(raw) else { return nil }
    return (raw + (number(offset) ?? 0)) * (number(scale) ?? 1)
}

/// ACPI lid state file contents: "state:      closed".
public func lidIsClosed(acpiState: String) -> Bool {
    acpiState.lowercased().contains("closed")
}
