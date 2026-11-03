import Foundation

/// `AppsUseLightTheme` under HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize:
/// 0 means dark, 1 means light. The value is missing on a fresh profile, which is light.
public func windowsAppearance(appsUseLightTheme: UInt32?) -> Appearance {
    appsUseLightTheme == 0 ? .dark : .light
}

/// The value both theme settings (apps and system) get for an appearance.
public func windowsThemeValue(for appearance: Appearance) -> UInt32 {
    appearance == .dark ? 0 : 1
}

/// The command stored in the HKCU Run key. The path is quoted because it may contain spaces.
public func windowsRunCommand(executablePath: String) -> String {
    "\"\(executablePath)\""
}
