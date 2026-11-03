import Foundation
import SmartModeCore
import WinSDK
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct ApplyError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Windows has one switch for apps and one for the taskbar and Start menu; set both, then tell
/// running programs the theme changed. There is no ambient light reading yet, so the sun and
/// clouds decide alone.
struct WindowsServices: PlatformServices {
    func currentAppearance() -> Appearance {
        windowsAppearance(appsUseLightTheme: readRegistryDWORD(RegistryPaths.personalize, "AppsUseLightTheme"))
    }

    func apply(_ appearance: Appearance) throws {
        let value = windowsThemeValue(for: appearance)
        for name in ["AppsUseLightTheme", "SystemUsesLightTheme"] {
            guard writeRegistryDWORD(RegistryPaths.personalize, name, value) else {
                throw ApplyError(message: "couldn't write \(name) to the registry")
            }
        }
        withWide("ImmersiveColorSet") { setting in
            _ = SendMessageTimeoutW(HWND(bitPattern: 0xFFFF), UINT(WM_SETTINGCHANGE), 0,
                                    LPARAM(Int(bitPattern: setting)), UINT(SMTO_ABORTIFHUNG), 100, nil)
        }
    }

    func readLux(now: Date) -> Double? { nil }

    /// The message loop never drains the Dispatch main queue, so networking uses plain completion
    /// handlers and hops back to the UI thread with `onMain`.
    func fetch(_ url: URL, _ completion: @escaping (Data?) -> Void) {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("SmartMode", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { data, response, _ in
            let ok = (response as? HTTPURLResponse).map { (200..<300).contains($0.statusCode) } ?? false
            onMain { completion(ok ? data : nil) }
        }.resume()
    }
}

enum Autostart {
    private static let name = "SmartMode"

    static var isEnabled: Bool { readRegistryString(RegistryPaths.run, name) != nil }

    static func set(_ enabled: Bool) throws {
        if enabled {
            guard writeRegistryString(RegistryPaths.run, name, windowsRunCommand(executablePath: executablePath())) else {
                throw ApplyError(message: "couldn't write the Run registry key")
            }
        } else {
            deleteRegistryValue(RegistryPaths.run, name)
        }
    }
}
