import SwiftUI

@main
struct SmartModeApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuView(model: model)
        } label: {
            // A warning triangle replaces the normal glyph while the app can't do anything.
            Label("Smart Mode",
                  systemImage: model.needsLocation ? "exclamationmark.triangle.fill" : "circle.lefthalf.filled")
        }
    }
}
