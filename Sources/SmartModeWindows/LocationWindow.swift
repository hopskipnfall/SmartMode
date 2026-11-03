import Foundation
import SmartModeCore
import WinSDK

private enum ControlID {
    static let search = 1          // IDOK, so Enter in the box presses it
    static let query = 101
    static let results = 103
    static let message = 104
    static let current = 105
}

/// Search for a place by name or type coordinates; double-click a result to use it.
final class LocationWindow {
    private let model: AppModel
    private(set) var window: HWND?
    private var query: HWND?
    private var list: HWND?
    private var message: HWND?
    private var current: HWND?
    private var places: [Place] = []
    private var searchID = 0

    init(model: AppModel) {
        self.model = model
        registerWindowClass("SmartModeLocation", proc: locationProc)
    }

    func show() {
        if window == nil { build() }
        setWindowText(query, "")
        setWindowText(message, "")
        setWindowText(current, "Current: \(model.locationLabel ?? "not set")")
        clearResults()
        ShowWindow(window, SW_SHOW)
        SetForegroundWindow(window)
        SetFocus(query)
    }

    private func child(_ className: String, _ text: String, style: Int32, x: Int32, y: Int32, width: Int32, height: Int32,
                       id: Int, extended: DWORD = 0) -> HWND? {
        let control = withWide(className) { classPointer in
            withWide(text) { textPointer in
                CreateWindowExW(extended, classPointer, textPointer, DWORD(WS_CHILD | WS_VISIBLE | style),
                                x, y, width, height, window, HMENU(bitPattern: id), GetModuleHandleW(nil), nil)
            }
        }
        setFont(control)
        return control
    }

    private func build() {
        window = withWide("SmartModeLocation") { classPointer in
            withWide("Set Location") {
                CreateWindowExW(0, classPointer, $0, DWORD(WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU),
                                CW_USEDEFAULT, CW_USEDEFAULT, 480, 440, nil, nil, GetModuleHandleW(nil), nil)
            }
        }
        _ = child("STATIC", "Search for a city or place, or type coordinates such as 35.69, 139.69.",
                  style: 0, x: 16, y: 14, width: 440, height: 36, id: 100)
        query = child("EDIT", "", style: WS_TABSTOP | WS_BORDER | Int32(ES_AUTOHSCROLL),
                      x: 16, y: 56, width: 350, height: 26, id: ControlID.query)
        _ = child("BUTTON", "Search", style: WS_TABSTOP | Int32(BS_DEFPUSHBUTTON),
                  x: 376, y: 55, width: 80, height: 28, id: ControlID.search)
        message = child("STATIC", "", style: 0, x: 16, y: 92, width: 440, height: 36, id: ControlID.message)
        list = child("LISTBOX", "", style: WS_TABSTOP | WS_BORDER | WS_VSCROLL | Int32(LBS_NOTIFY),
                     x: 16, y: 132, width: 440, height: 200, id: ControlID.results)
        _ = child("STATIC", "Double-click a result to use it.", style: 0, x: 16, y: 338, width: 440, height: 20, id: 106)
        current = child("STATIC", "", style: 0, x: 16, y: 362, width: 440, height: 20, id: ControlID.current)
        locationWindowInstance = self
    }

    private func clearResults() {
        places = []
        SendMessageW(list, UINT(LB_RESETCONTENT), 0, 0)
    }

    fileprivate func search() {
        let text = windowText(query)
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        searchID += 1
        let id = searchID
        setWindowText(message, "Searching…")
        clearResults()
        model.search(text) { [self] found, failed in
            guard id == searchID else { return }   // a newer search superseded this one
            setWindowText(message, failed ? "Couldn't search. Check your internet connection, or type coordinates like 35.69, 139.69."
                          : found.isEmpty ? "No places found. Try a nearby city, or type coordinates like 35.69, 139.69." : "")
            places = found
            for place in found {
                let label = "\(place.label)  (\(String(format: "%.2f, %.2f", place.latitude, place.longitude)))"
                withWide(label) { _ = SendMessageW(list, UINT(LB_ADDSTRING), 0, LPARAM(Int(bitPattern: $0))) }
            }
        }
    }

    fileprivate func pickSelected() {
        let index = Int(SendMessageW(list, UINT(LB_GETCURSEL), 0, 0))
        guard places.indices.contains(index) else { return }
        model.choose(places[index])
        ShowWindow(window, SW_HIDE)
    }

    fileprivate func hide() { ShowWindow(window, SW_HIDE) }
}

private var locationWindowInstance: LocationWindow?

private let locationProc: WNDPROC = { hwnd, message, wParam, lParam in
    switch message {
    case UINT(WM_COMMAND):
        let id = Int(wParam & 0xFFFF), notification = Int((wParam >> 16) & 0xFFFF)
        if id == ControlID.search { locationWindowInstance?.search() }
        else if id == ControlID.results && notification == Int(LBN_DBLCLK) { locationWindowInstance?.pickSelected() }
        return 0
    case UINT(WM_CLOSE):
        // Closing hides the window so it can be shown again.
        locationWindowInstance?.hide()
        return 0
    default:
        return DefWindowProcW(hwnd, message, wParam, lParam)
    }
}
