import AppKit

final class OnboardingController: NSObject {
    static let shared = OnboardingController()

    private var window: NSWindow?
    private var pollTimer: Timer?

    private override init() {
        super.init()
    }

    func showIfNeeded() {
        guard !Preferences.onboardingDone || !AccessibilityHelper.hasAllPermissions else { return }
        show()
    }

    func show() {
        if window == nil {
            window = makeWindow()
        }
        refreshStatus()
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        startPolling()
    }

    private func makeWindow() -> NSWindow {
        let width: CGFloat = 500
        let height: CGFloat = 500
        let rect = NSRect(x: 0, y: 0, width: width, height: height)
        let window = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Triclick"
        window.isReleasedWhenClosed = false
        window.level = .floating

        let content = NSView(frame: rect)

        let title = NSTextField(labelWithString: "Three fingers. Middle click.")
        title.font = .systemFont(ofSize: 22, weight: .semibold)
        title.alignment = .center
        title.translatesAutoresizingMaskIntoConstraints = false

        let body = NSTextField(wrappingLabelWithString:
            "Triclick needs Accessibility and Input Monitoring.\n\n" +
            "If a toggle looks ON but Triclick still says ✗, macOS is stuck on an old grant. " +
            "Use Reset Permissions below — that clears it — then add Triclick again with the + button."
        )
        body.font = .systemFont(ofSize: 13)
        body.alignment = .left
        body.translatesAutoresizingMaskIntoConstraints = false

        let status = NSTextField(wrappingLabelWithString: statusText())
        status.tag = 100
        status.font = .systemFont(ofSize: 13, weight: .medium)
        status.alignment = .center
        status.translatesAutoresizingMaskIntoConstraints = false

        let axButton = NSButton(title: "Open Accessibility", target: self, action: #selector(openAccessibility))
        axButton.bezelStyle = .rounded
        axButton.translatesAutoresizingMaskIntoConstraints = false

        let imButton = NSButton(title: "Open Input Monitoring", target: self, action: #selector(openInputMonitoring))
        imButton.bezelStyle = .rounded
        imButton.translatesAutoresizingMaskIntoConstraints = false

        let resetButton = NSButton(title: "Reset Permissions & Restart", target: self, action: #selector(resetPermissions))
        resetButton.bezelStyle = .rounded
        resetButton.translatesAutoresizingMaskIntoConstraints = false

        let restartButton = NSButton(title: "Restart Triclick", target: self, action: #selector(restart))
        restartButton.bezelStyle = .rounded
        restartButton.translatesAutoresizingMaskIntoConstraints = false
        restartButton.keyEquivalent = "\r"

        let continueButton = NSButton(title: "Continue", target: self, action: #selector(finish))
        continueButton.bezelStyle = .rounded
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        continueButton.isEnabled = AccessibilityHelper.hasAllPermissions
        continueButton.tag = 101

        content.addSubview(title)
        content.addSubview(body)
        content.addSubview(status)
        content.addSubview(axButton)
        content.addSubview(imButton)
        content.addSubview(resetButton)
        content.addSubview(restartButton)
        content.addSubview(continueButton)
        window.contentView = content

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: content.topAnchor, constant: 22),
            title.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28),
            title.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28),

            body.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 12),
            body.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28),
            body.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28),

            status.topAnchor.constraint(equalTo: body.bottomAnchor, constant: 14),
            status.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28),
            status.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28),

            axButton.topAnchor.constraint(equalTo: status.bottomAnchor, constant: 14),
            axButton.centerXAnchor.constraint(equalTo: content.centerXAnchor),

            imButton.topAnchor.constraint(equalTo: axButton.bottomAnchor, constant: 8),
            imButton.centerXAnchor.constraint(equalTo: content.centerXAnchor),

            resetButton.topAnchor.constraint(equalTo: imButton.bottomAnchor, constant: 12),
            resetButton.centerXAnchor.constraint(equalTo: content.centerXAnchor),

            restartButton.topAnchor.constraint(equalTo: resetButton.bottomAnchor, constant: 8),
            restartButton.centerXAnchor.constraint(equalTo: content.centerXAnchor),

            continueButton.topAnchor.constraint(equalTo: restartButton.bottomAnchor, constant: 8),
            continueButton.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            continueButton.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -18)
        ])

        return window
    }

    private func statusText() -> String {
        let ax = AccessibilityHelper.isTrusted ? "✓" : "✗"
        let im = AccessibilityHelper.hasInputMonitoring ? "✓" : "✗"
        return "Accessibility \(ax)   Input Monitoring \(im)"
    }

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            self?.refreshStatus()
        }
    }

    private func refreshStatus() {
        guard let content = window?.contentView else { return }
        let ready = AccessibilityHelper.hasAllPermissions

        if let status = content.viewWithTag(100) as? NSTextField {
            status.stringValue = statusText()
            status.textColor = ready ? .systemGreen : .secondaryLabelColor
        }
        if let button = content.viewWithTag(101) as? NSButton {
            button.isEnabled = ready
        }

        if ready {
            AppDelegate.shared?.startEngineIfNeeded()
        }
    }

    @objc private func openAccessibility() {
        AccessibilityHelper.requestTrust(prompt: true)
        AccessibilityHelper.openAccessibilitySettings()
    }

    @objc private func openInputMonitoring() {
        _ = AccessibilityHelper.requestInputMonitoring()
        AccessibilityHelper.openInputMonitoringSettings()
    }

    @objc private func resetPermissions() {
        pollTimer?.invalidate()
        AccessibilityHelper.resetTCCAndRelaunch()
    }

    @objc private func restart() {
        pollTimer?.invalidate()
        AccessibilityHelper.relaunchApp()
    }

    @objc private func finish() {
        guard AccessibilityHelper.hasAllPermissions else { return }
        Preferences.onboardingDone = true
        if Preferences.launchAtLogin {
            LoginItem.syncFromPreferences()
        }
        pollTimer?.invalidate()
        pollTimer = nil
        window?.close()
        AppDelegate.shared?.startEngineIfNeeded()
    }
}
