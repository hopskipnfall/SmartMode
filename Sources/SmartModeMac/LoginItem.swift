import ServiceManagement

/// Registers the app itself as a login item. macOS keys this to the app's path, so it works
/// best once SmartMode.app lives somewhere stable such as /Applications.
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
