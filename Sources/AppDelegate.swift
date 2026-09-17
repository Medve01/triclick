import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate?

    private var menuBar: MenuBarController?
    private var engineStarted = false
    private var accessibilityTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        NSApp.setActivationPolicy(.accessory)

        menuBar = MenuBarController(appDelegate: self)
        OnboardingController.shared.showIfNeeded()

        if AccessibilityHelper.isTrusted {
            startEngineIfNeeded()
        } else {
            // Keep watching — user may grant permission without finishing onboarding.
            accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
                guard AccessibilityHelper.isTrusted else { return }
                self?.startEngineIfNeeded()
                self?.menuBar?.reload()
            }
        }

        // Heal menu state when the user returns from System Settings.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.menuBar?.reload()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        GestureEngine.shared.stop()
        DeviceMonitor.shared.stop()
    }

    func startEngineIfNeeded() {
        guard AccessibilityHelper.isTrusted else { return }
        guard !engineStarted else {
            // Re-install taps in case macOS disabled them.
            GestureEngine.shared.start()
            return
        }
        engineStarted = true
        GestureEngine.shared.start()
        DeviceMonitor.shared.start()
        menuBar?.reload()
        accessibilityTimer?.invalidate()
        accessibilityTimer = nil
        NSLog("Triclick: engine started")
    }
}
