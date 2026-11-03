import Foundation
import SmartModeCore

/// The bits of the desktop that differ per platform: reading and setting the appearance,
/// the ambient light sensor, opening links and files, and starting at login.
enum Shell {
    /// Runs a program and returns its trimmed stdout, or nil if it couldn't run or exited non-zero.
    @discardableResult
    static func run(_ program: String, _ arguments: [String]) -> (output: String, status: Int32)? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [program] + arguments
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        do { try process.run() } catch { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let text = String(decoding: process.terminationStatus == 0 ? data : errData, as: UTF8.self)
        return (text.trimmingCharacters(in: .whitespacesAndNewlines), process.terminationStatus)
    }

    static func open(_ target: String) {
        // Detached: xdg-open can outlive the click and must not block the UI.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["xdg-open", target]
        try? process.run()
    }
}

struct ApplyError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct LinuxServices: PlatformServices {
    private let sensor = SensorProvider()

    func currentAppearance() -> Appearance { Applier.current() }
    func apply(_ appearance: Appearance) throws { try Applier.set(appearance) }
    func readLux(now: Date) -> Double? { sensor.read(now: now) }
    func fetch(_ url: URL, _ completion: @escaping (Data?) -> Void) { SmartModeLinux.fetch(url, completion) }
}

enum Applier {
    static let desktop = LinuxDesktop.detect(currentDesktop: ProcessInfo.processInfo.environment["XDG_CURRENT_DESKTOP"])

    private static func get(_ schema: String, _ key: String) -> String? {
        guard let result = Shell.run("gsettings", ["get", schema, key]), result.status == 0 else { return nil }
        return result.output
    }

    static func current() -> Appearance {
        currentAppearance(for: desktop,
                          colorScheme: get("org.gnome.desktop.interface", "color-scheme"),
                          gtkTheme: desktop == .cinnamon ? get("org.cinnamon.desktop.interface", "gtk-theme") : nil)
    }

    static func set(_ appearance: Appearance) throws {
        let theme = desktop == .cinnamon ? get("org.cinnamon.desktop.interface", "gtk-theme") : nil
        let currentTheme = theme.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "'")) }
        for change in gsettingsChanges(for: desktop, appearance: appearance, currentGtkTheme: currentTheme) {
            guard let result = Shell.run("gsettings", ["set"] + change) else {
                throw ApplyError(message: "gsettings not found")
            }
            if result.status != 0 { throw ApplyError(message: result.output) }
        }
    }
}

/// Reads an ambient light sensor through the kernel's industrial I/O (IIO) interface, the
/// standard Linux route that iio-sensor-proxy uses too. Plenty of machines have none.
final class SensorProvider {
    private var window = RollingWindow(duration: 60)
    private let root = "/sys/bus/iio/devices"

    private func read(_ path: String) -> String? { try? String(contentsOfFile: path, encoding: .utf8) }

    private func lux() -> Double? {
        let devices = (try? FileManager.default.contentsOfDirectory(atPath: root)) ?? []
        for device in devices.sorted() {
            let base = "\(root)/\(device)/in_illuminance"
            let value = illuminanceLux(input: read(base + "_input"), raw: read(base + "_raw"),
                                       scale: read(base + "_scale"), offset: read(base + "_offset"))
            if let value { return value }
        }
        return nil
    }

    private func lidClosed() -> Bool {
        let lids = (try? FileManager.default.contentsOfDirectory(atPath: "/proc/acpi/button/lid")) ?? []
        return lids.contains { read("/proc/acpi/button/lid/\($0)/state").map(lidIsClosed) ?? false }
    }

    func read(now: Date) -> Double? {
        // With the lid closed the sensor sees nothing; don't let that vote "dark".
        guard !lidClosed() else { return nil }
        if let value = lux() { window.add(value, at: now) }
        return window.median(at: now)
    }
}

enum Autostart {
    private static var directory: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/autostart")
    }
    static var file: URL { directory.appendingPathComponent("smart-mode.desktop") }
    static var executablePath: String {
        (try? FileManager.default.destinationOfSymbolicLink(atPath: "/proc/self/exe")) ?? CommandLine.arguments[0]
    }

    static var isEnabled: Bool { FileManager.default.fileExists(atPath: file.path) }

    static func set(_ enabled: Bool) throws {
        if enabled {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try autostartEntry(executablePath: executablePath).write(to: file, atomically: true, encoding: .utf8)
        } else if isEnabled {
            try FileManager.default.removeItem(at: file)
        }
    }
}
