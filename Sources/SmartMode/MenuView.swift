import SwiftUI

struct MenuView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ForEach(Array(model.lines.enumerated()), id: \.offset) { _, line in
            Text(line)
        }
        if let error = model.configError {
            Divider()
            Text(error)
        }
        Divider()
        Button(model.paused ? "Resume auto switching" : "Pause auto switching") {
            model.paused.toggle()
        }
        Toggle("Launch at login", isOn: Binding(
            get: { model.launchAtLogin },
            set: { model.setLaunchAtLogin($0) }
        ))
        if let error = model.loginItemError {
            Text(error)
        }
        Button("Set location…") { model.openLocationWindow() }
        Button("Open config…") { model.openConfig() }
        Button("Quit") { NSApplication.shared.terminate(nil) }
    }
}
