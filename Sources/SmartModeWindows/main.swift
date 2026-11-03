import SmartModeCore
import WinSDK

private let model = AppModel()
private var tray: Tray?
private var taskbarCreated: UINT = 0
private let tickTimer: UINT_PTR = 1

private let mainProc: WNDPROC = { hwnd, message, wParam, lParam in
    switch message {
    case WM_TRAY:
        // For the legacy notify-icon callback, lParam's low word is the mouse message.
        let mouse = UInt32(lParam & 0xFFFF)
        if mouse == UInt32(WM_RBUTTONUP) || mouse == UInt32(WM_LBUTTONUP) { tray?.showMenu() }
        return 0
    case WM_RUN_ON_MAIN:
        runOnMainMessage(lParam)
        return 0
    case UINT(WM_TIMER):
        model.tick()
        return 0
    case UINT(WM_COMMAND):
        tray?.handle(command: UInt16(wParam & 0xFFFF))
        return 0
    case UINT(WM_DESTROY):
        tray?.remove()
        PostQuitMessage(0)
        return 0
    default:
        if message == taskbarCreated { tray?.add() }   // Explorer restarted
        return DefWindowProcW(hwnd, message, wParam, lParam)
    }
}

registerWindowClass("SmartModeMain", proc: mainProc)
taskbarCreated = withWide("TaskbarCreated") { RegisterWindowMessageW($0) }
mainWindow = withWide("SmartModeMain") { classPointer in
    withWide("SmartMode") {
        // A hidden top-level window: it only receives the tray, timer and callback messages.
        CreateWindowExW(0, classPointer, $0, 0, 0, 0, 0, 0, nil, nil, GetModuleHandleW(nil), nil)
    }
}
tray = Tray(model: model)
model.start()
SetTimer(mainWindow, tickTimer, 10_000, nil)

var message = MSG()
while GetMessageW(&message, nil, 0, 0) {
    if let tray, tray.isLocationDialogMessage(&message) { continue }
    TranslateMessage(&message)
    DispatchMessageW(&message)
}
