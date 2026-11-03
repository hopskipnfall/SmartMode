import Foundation
import WinSDK

/// A null-terminated UTF-16 copy of `string`.
func wide(_ string: String) -> [UInt16] { Array(string.utf16) + [0] }

func withWide<R>(_ string: String, _ body: (UnsafePointer<UInt16>) -> R) -> R {
    wide(string).withUnsafeBufferPointer { body($0.baseAddress!) }
}

/// Closures cross into the message loop as a retained box in a window message's lParam.
private final class Box {
    let run: () -> Void
    init(_ run: @escaping () -> Void) { self.run = run }
}

let WM_RUN_ON_MAIN = UINT(WM_APP) + 2

/// The hidden window that owns the tray icon, the timer and cross-thread callbacks.
var mainWindow: HWND?

/// Runs `work` on the UI thread. Safe to call from any thread.
func onMain(_ work: @escaping () -> Void) {
    let pointer = Unmanaged.passRetained(Box(work)).toOpaque()
    PostMessageW(mainWindow, WM_RUN_ON_MAIN, 0, LPARAM(Int(bitPattern: pointer)))
}

func runOnMainMessage(_ lParam: LPARAM) {
    guard let pointer = UnsafeRawPointer(bitPattern: Int(lParam)) else { return }
    Unmanaged<Box>.fromOpaque(pointer).takeRetainedValue().run()
}

func registerWindowClass(_ name: String, proc: WNDPROC) {
    // The class name must outlive the registration, so it is allocated and never freed.
    let units = wide(name)
    let buffer = UnsafeMutablePointer<UInt16>.allocate(capacity: units.count)
    buffer.initialize(from: units, count: units.count)

    var windowClass = WNDCLASSW()
    windowClass.lpfnWndProc = proc
    windowClass.hInstance = GetModuleHandleW(nil)
    windowClass.hCursor = LoadCursorW(nil, UnsafePointer<UInt16>(bitPattern: 32512))   // IDC_ARROW
    windowClass.hbrBackground = HBRUSH(bitPattern: Int(COLOR_WINDOW) + 1)
    windowClass.lpszClassName = UnsafePointer(buffer)
    RegisterClassW(&windowClass)
}

func setFont(_ control: HWND?) {
    let font = GetStockObject(DEFAULT_GUI_FONT)
    SendMessageW(control, UINT(WM_SETFONT), WPARAM(UInt(bitPattern: font)), 1)
}

func windowText(_ control: HWND?) -> String {
    let length = Int(GetWindowTextLengthW(control))
    var buffer = [UInt16](repeating: 0, count: length + 1)
    GetWindowTextW(control, &buffer, Int32(buffer.count))
    return String(decoding: buffer.prefix(length), as: UTF16.self)
}

func setWindowText(_ control: HWND?, _ text: String) {
    withWide(text) { _ = SetWindowTextW(control, $0) }
}

// MARK: - Registry

private let hkcu = HKEY(bitPattern: UInt(0x8000_0001))
private let personalizeKey = "Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize"
private let runKey = "Software\\Microsoft\\Windows\\CurrentVersion\\Run"

func readRegistryDWORD(_ subKey: String, _ name: String) -> UInt32? {
    var data: DWORD = 0
    var size = DWORD(MemoryLayout<DWORD>.size)
    let status = withWide(subKey) { key in
        withWide(name) { RegGetValueW(hkcu, key, $0, DWORD(RRF_RT_REG_DWORD), nil, &data, &size) }
    }
    return status == 0 ? UInt32(data) : nil
}

func writeRegistryDWORD(_ subKey: String, _ name: String, _ value: UInt32) -> Bool {
    var data = DWORD(value)
    let status = withWide(subKey) { key in
        withWide(name) { RegSetKeyValueW(hkcu, key, $0, DWORD(REG_DWORD), &data, DWORD(MemoryLayout<DWORD>.size)) }
    }
    return status == 0
}

func readRegistryString(_ subKey: String, _ name: String) -> String? {
    var size: DWORD = 0
    let probe = withWide(subKey) { key in
        withWide(name) { RegGetValueW(hkcu, key, $0, DWORD(RRF_RT_REG_SZ), nil, nil, &size) }
    }
    guard probe == 0, size > 0 else { return nil }
    var buffer = [UInt16](repeating: 0, count: Int(size) / 2 + 1)
    let status = withWide(subKey) { key in
        withWide(name) { RegGetValueW(hkcu, key, $0, DWORD(RRF_RT_REG_SZ), nil, &buffer, &size) }
    }
    return status == 0 ? String(decodingCString: buffer, as: UTF16.self) : nil
}

func writeRegistryString(_ subKey: String, _ name: String, _ value: String) -> Bool {
    let units = wide(value)
    let status = withWide(subKey) { key in
        withWide(name) { name in
            units.withUnsafeBytes {
                RegSetKeyValueW(hkcu, key, name, DWORD(REG_SZ), $0.baseAddress, DWORD($0.count))
            }
        }
    }
    return status == 0
}

func deleteRegistryValue(_ subKey: String, _ name: String) {
    withWide(subKey) { key in withWide(name) { _ = RegDeleteKeyValueW(hkcu, key, $0) } }
}

enum RegistryPaths {
    static let personalize = personalizeKey
    static let run = runKey
}

// MARK: - Shell

enum Shell {
    /// Opens a file or URL with whatever Windows associates with it.
    static func open(_ target: String) {
        let result = withWide("open") { verb in
            withWide(target) { ShellExecuteW(nil, verb, $0, nil, nil, Int32(SW_SHOWNORMAL)) }
        }
        // 32 and below means failure, e.g. no program is associated with .yaml.
        if Int(bitPattern: result) <= 32 {
            withWide("open") { verb in
                withWide("notepad.exe") { notepad in
                    withWide(target) { _ = ShellExecuteW(nil, verb, notepad, $0, nil, Int32(SW_SHOWNORMAL)) }
                }
            }
        }
    }
}

func executablePath() -> String {
    var buffer = [UInt16](repeating: 0, count: 1024)
    let length = Int(GetModuleFileNameW(nil, &buffer, DWORD(buffer.count)))
    return String(decoding: buffer.prefix(length), as: UTF16.self)
}
