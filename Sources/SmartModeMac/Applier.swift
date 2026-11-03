import Foundation
import SmartModeCore

enum Applier {
    static func current() -> Appearance {
        // AppleInterfaceStyle is "Dark" in dark mode and absent in light mode.
        let style = UserDefaults.standard.string(forKey: "AppleInterfaceStyle")
        return style == "Dark" ? .dark : .light
    }

    static func set(_ appearance: Appearance) throws {
        let value = appearance == .dark ? "true" : "false"
        let script = "tell application \"System Events\" to tell appearance preferences to set dark mode to \(value)"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let stderr = Pipe()
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            let message = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "osascript failed"
            throw NSError(domain: "Applier", code: Int(process.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: message.trimmingCharacters(in: .whitespacesAndNewlines)])
        }
    }
}
