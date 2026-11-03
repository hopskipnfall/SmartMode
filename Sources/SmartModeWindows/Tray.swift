import Foundation
import SmartModeCore
import WinSDK

let WM_TRAY = UINT(WM_APP) + 1

private enum Command: UInt16 {
    case pause = 1, launchAtLogin, setLocation, openConfig, reportIssue, quit
}

/// The notification-area icon and its right-click menu. The menu is built fresh on each click.
final class Tray {
    private let model: AppModel
    private let locationWindow: LocationWindow
    private var lastWarning: Bool?

    init(model: AppModel) {
        self.model = model
        locationWindow = LocationWindow(model: model)
        add()
        model.onChange = { [self] in refresh() }
    }

    private func iconData() -> NOTIFYICONDATAW {
        var data = NOTIFYICONDATAW()
        data.cbSize = DWORD(MemoryLayout<NOTIFYICONDATAW>.size)
        data.hWnd = mainWindow
        data.uID = 1
        data.uFlags = UINT(NIF_ICON | NIF_MESSAGE | NIF_TIP)
        data.uCallbackMessage = WM_TRAY
        data.hIcon = model.needsLocation ? Icons.warning : Icons.normal
        let tip = Array("SmartMode".utf16)
        withUnsafeMutableBytes(of: &data.szTip) { raw in
            let units = raw.bindMemory(to: UInt16.self)
            for (index, unit) in tip.enumerated() { units[index] = unit }
            units[tip.count] = 0
        }
        return data
    }

    /// Also called when Explorer restarts and the icon has to be put back.
    func add() {
        var data = iconData()
        Shell_NotifyIconW(DWORD(NIM_ADD), &data)
        lastWarning = model.needsLocation
    }

    func remove() {
        var data = iconData()
        Shell_NotifyIconW(DWORD(NIM_DELETE), &data)
    }

    private func refresh() {
        guard lastWarning != model.needsLocation else { return }
        lastWarning = model.needsLocation
        var data = iconData()
        Shell_NotifyIconW(DWORD(NIM_MODIFY), &data)
    }

    func showMenu() {
        guard let menu = CreatePopupMenu() else { return }
        defer { DestroyMenu(menu) }

        func item(_ text: String, id: UInt64 = 0, flags: Int32 = MF_STRING) {
            withWide(text) { _ = AppendMenuW(menu, UINT(flags), id, $0) }
        }
        func text(_ label: String) { item(label, flags: MF_STRING | MF_GRAYED) }
        func separator() { AppendMenuW(menu, UINT(MF_SEPARATOR), 0, nil) }
        func button(_ label: String, _ command: Command, checked: Bool = false) {
            item(label, id: UInt64(command.rawValue), flags: MF_STRING | (checked ? MF_CHECKED : MF_UNCHECKED))
        }

        if model.needsLocation {
            button("Set a location to get started…", .setLocation)
            text("SmartMode does nothing until it knows where you are.")
            separator()
        }
        model.lines.forEach(text)
        for error in [model.configError, model.locationSaveError] {
            if let error { separator(); text(error) }
        }
        separator()
        button(model.paused ? "Resume auto switching" : "Pause auto switching", .pause)
        button("Launch at login", .launchAtLogin, checked: model.launchAtLogin)
        if let error = model.loginItemError { text(error) }
        button("Set location…", .setLocation)
        button("Open config…", .openConfig)
        button("Report an issue…", .reportIssue)
        button("Quit", .quit)

        var point = POINT()
        GetCursorPos(&point)
        // Without this the menu doesn't close when the user clicks elsewhere.
        SetForegroundWindow(mainWindow)
        TrackPopupMenu(menu, UINT(TPM_RIGHTBUTTON | TPM_BOTTOMALIGN), point.x, point.y, 0, mainWindow, nil)
        PostMessageW(mainWindow, UINT(WM_NULL), 0, 0)
    }

    func handle(command id: UInt16) {
        switch Command(rawValue: id) {
        case .pause: model.paused.toggle()
        case .launchAtLogin: model.setLaunchAtLogin(!model.launchAtLogin)
        case .setLocation: locationWindow.show()
        case .openConfig: model.openConfig()
        case .reportIssue: model.openBugReport()
        case .quit: DestroyWindow(mainWindow)
        case nil: break
        }
    }

    /// Whether `window` is the location window, so Enter and Tab work inside it.
    func isLocationDialogMessage(_ message: inout MSG) -> Bool {
        guard let window = locationWindow.window else { return false }
        return IsDialogMessageW(window, &message)
    }
}
