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

        if AccessibilityHelper.hasAllPermissions {
            startEngineIfNeeded()
        } else {
            accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
                guard AccessibilityHelper.hasAllPermissions else { return }
                self?.startEngineIfNeeded()
                self?.menuBar?.reload()
            }
        }

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
        guard AccessibilityHelper.hasAllPermissions else { return }
        guard !engineStarted else {
            GestureEngine.shared.start()
            return
        }
        engineStarted = true
        GestureEngine.shared.start()
        DeviceMonitor.shared.start()
        menuBar?.reload()
        menuBar?.startFingerHUD()
        accessibilityTimer?.invalidate()
        accessibilityTimer = nil
        NSLog("Triclick: engine started")
    }
}
