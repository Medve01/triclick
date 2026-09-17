import AppKit
import ApplicationServices
import IOKit
import IOKit.hid

enum AccessibilityHelper {
    /// Fresh TCC check — `AXIsProcessTrusted()` can cache stale false for the process lifetime.
    static var isTrusted: Bool {
        AXIsProcessTrustedWithOptions(nil)
    }

    @discardableResult
    static func requestTrust(prompt: Bool = true) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        openSettings(urls: [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"
        ])
    }

    static func openInputMonitoringSettings() {
        openSettings(urls: [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ListenEvent"
        ])
    }

    static var hasInputMonitoring: Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    @discardableResult
    static func requestInputMonitoring() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    static var hasAllPermissions: Bool {
        isTrusted && hasInputMonitoring
    }

    /// Clears stale TCC rows (ad-hoc CDHash ghosts) then relaunches so a fresh prompt can appear.
    static func resetTCCAndRelaunch() {
        let bundleID = Bundle.main.bundleIdentifier ?? "dev.medve01.Triclick"
        let appURL = Bundle.main.bundleURL

        // Detach: reset AFTER we quit, otherwise tccd can race the still-running process.
        let script = """
        #!/bin/zsh
        sleep 0.6
        /usr/bin/tccutil reset Accessibility \(bundleID) >/dev/null 2>&1 || true
        /usr/bin/tccutil reset ListenEvent \(bundleID) >/dev/null 2>&1 || true
        /usr/bin/open \(appURL.path.shellEscaped)
        """

        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("triclick-tcc-reset.sh")
        do {
            try script.write(to: tmp, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tmp.path)
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
            proc.arguments = [tmp.path]
            try proc.run()
        } catch {
            NSLog("Triclick: failed to schedule TCC reset: \(error.localizedDescription)")
        }

        NSApp.terminate(nil)
    }

    static func relaunchApp() {
        let url = Bundle.main.bundleURL
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            if let error {
                NSLog("Triclick: relaunch failed: \(error.localizedDescription)")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                NSApp.terminate(nil)
            }
        }
    }

    private static func openSettings(urls: [String]) {
        for raw in urls {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}

private extension String {
    var shellEscaped: String {
        "'" + replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
