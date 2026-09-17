import ServiceManagement

enum LoginItem {
    static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    static func setEnabled(_ enabled: Bool) {
        guard #available(macOS 13.0, *) else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            Preferences.launchAtLogin = enabled
        } catch {
            NSLog("Triclick: login item update failed: \(error.localizedDescription)")
        }
    }

    static func syncFromPreferences() {
        setEnabled(Preferences.launchAtLogin)
    }
}
