import CGtk
import Foundation
import SmartModeCore

/// The tray icon and its menu. The menu is only rebuilt when its contents change, because
/// replacing it would close it under the user's pointer.
final class Tray {
    private let model: AppModel
    private let indicator: UnsafeMutablePointer<AppIndicator>
    private let locationWindow: LocationWindow
    private var lastSignature = ""

    init(model: AppModel) {
        self.model = model
        locationWindow = LocationWindow(model: model)
        indicator = app_indicator_new("smart-mode", "weather-clear-night-symbolic", APP_INDICATOR_CATEGORY_APPLICATION_STATUS)
        app_indicator_set_status(indicator, APP_INDICATOR_STATUS_ACTIVE)
        app_indicator_set_title(indicator, "SmartMode")
        model.onChange = { [self] in refresh() }
        refresh()
    }

    private func refresh() {
        let signature = ([model.needsLocation, model.paused, model.launchAtLogin].map(String.init) + model.lines
            + [model.configError ?? "", model.locationSaveError ?? "", model.loginItemError ?? ""]).joined(separator: "\n")
        guard signature != lastSignature else { return }
        lastSignature = signature
        app_indicator_set_icon_full(indicator, model.needsLocation ? "dialog-warning-symbolic" : "weather-clear-night-symbolic", "SmartMode")
        app_indicator_set_menu(indicator, buildMenu())
    }

    private func buildMenu() -> UnsafeMutablePointer<GtkMenu> {
        let menu = UnsafeMutableRawPointer(gtk_menu_new()!).assumingMemoryBound(to: GtkMenu.self)
        func add(_ item: UnsafeMutablePointer<GtkWidget>?) {
            gtk_menu_shell_append(UnsafeMutableRawPointer(menu).assumingMemoryBound(to: GtkMenuShell.self), item)
            gtk_widget_show(item)
        }
        func text(_ label: String) {
            let item = gtk_menu_item_new_with_label(label)
            gtk_widget_set_sensitive(item, 0)
            add(item)
        }
        func separator() { add(gtk_separator_menu_item_new()) }
        func button(_ label: String, _ action: @escaping () -> Void) {
            let item = gtk_menu_item_new_with_label(label)
            connect(item, "activate", action)
            add(item)
        }

        if model.needsLocation {
            button("⚠ Set a location to get started…") { [self] in locationWindow.show() }
            text("SmartMode does nothing until it knows where you are.")
            separator()
        }
        model.lines.forEach(text)
        for error in [model.configError, model.locationSaveError] {
            if let error { separator(); text(error) }
        }
        separator()
        button(model.paused ? "Resume auto switching" : "Pause auto switching") { [self] in model.paused.toggle() }

        let login = gtk_check_menu_item_new_with_label("Launch at login")
        gtk_check_menu_item_set_active(UnsafeMutableRawPointer(login!).assumingMemoryBound(to: GtkCheckMenuItem.self), model.launchAtLogin ? 1 : 0)
        connect(login, "activate") { [self] in model.setLaunchAtLogin(!model.launchAtLogin) }
        add(login)
        if let error = model.loginItemError { text(error) }

        button("Set location…") { [self] in locationWindow.show() }
        button("Open config…") { [self] in model.openConfig() }
        button("Report an issue…") { [self] in model.openBugReport() }
        button("Quit") { gtk_main_quit() }
        return menu
    }
}
