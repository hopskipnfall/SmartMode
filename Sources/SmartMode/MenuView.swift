import SwiftUI

struct MenuView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        if model.needsLocation {
            Button {
                model.openLocationWindow()
            } label: {
                Label("Set a location to get started…", systemImage: "exclamationmark.triangle.fill")
            }
            Text("SmartMode does nothing until it knows where you are.")
            Divider()
        }
        ForEach(Array(model.lines.enumerated()), id: \.offset) { _, line in
            Text(line)
        }
        if let error = model.configError {
            Divider()
            Text(error)
        }
        if let error = model.locationSaveError {
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
        Button("About SmartMode") { AboutPanel.show() }
        Button("Quit") { NSApplication.shared.terminate(nil) }
    }
}
