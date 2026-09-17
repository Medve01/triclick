import AppKit

final class OnboardingController: NSObject {
    static let shared = OnboardingController()

    private var window: NSWindow?
    private var pollTimer: Timer?

    private override init() {
        super.init()
    }

    func showIfNeeded() {
        guard !Preferences.onboardingDone || !AccessibilityHelper.isTrusted else { return }
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
        let width: CGFloat = 460
        let height: CGFloat = 400
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
            "Triclick adds the missing middle mouse button to your Mac trackpad.\n\n" +
            "1. Click Open Accessibility Settings\n" +
            "2. Turn Triclick ON (toggle off/on if it was already on)\n" +
            "3. Click Restart Triclick — macOS only applies the permission after a relaunch"
        )
        body.font = .systemFont(ofSize: 13)
        body.alignment = .left
        body.translatesAutoresizingMaskIntoConstraints = false

        let status = NSTextField(labelWithString: statusText())
        status.tag = 100
        status.font = .systemFont(ofSize: 13, weight: .medium)
        status.alignment = .center
        status.translatesAutoresizingMaskIntoConstraints = false

        let grantButton = NSButton(title: "Open Accessibility Settings", target: self, action: #selector(openSettings))
        grantButton.bezelStyle = .rounded
        grantButton.translatesAutoresizingMaskIntoConstraints = false
        grantButton.tag = 102

        let restartButton = NSButton(title: "Restart Triclick", target: self, action: #selector(restart))
        restartButton.bezelStyle = .rounded
        restartButton.translatesAutoresizingMaskIntoConstraints = false
        restartButton.keyEquivalent = "\r"
        restartButton.tag = 103

        let continueButton = NSButton(title: "Continue", target: self, action: #selector(finish))
        continueButton.bezelStyle = .rounded
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        continueButton.isEnabled = AccessibilityHelper.isTrusted
        continueButton.tag = 101

        content.addSubview(title)
        content.addSubview(body)
        content.addSubview(status)
        content.addSubview(grantButton)
        content.addSubview(restartButton)
        content.addSubview(continueButton)
        window.contentView = content

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: content.topAnchor, constant: 28),
            title.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28),
            title.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28),

            body.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 16),
            body.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28),
            body.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28),

            status.topAnchor.constraint(equalTo: body.bottomAnchor, constant: 18),
            status.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28),
            status.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28),

            grantButton.topAnchor.constraint(equalTo: status.bottomAnchor, constant: 18),
            grantButton.centerXAnchor.constraint(equalTo: content.centerXAnchor),

            restartButton.topAnchor.constraint(equalTo: grantButton.bottomAnchor, constant: 10),
            restartButton.centerXAnchor.constraint(equalTo: content.centerXAnchor),

            continueButton.topAnchor.constraint(equalTo: restartButton.bottomAnchor, constant: 10),
            continueButton.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            continueButton.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -24)
        ])

        return window
    }

    private func statusText() -> String {
        if AccessibilityHelper.isTrusted {
            return "✓ Accessibility is granted — you can Continue"
        }
        return "Permission applies after Restart (even if the toggle is already ON)"
    }

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            self?.refreshStatus()
        }
    }

    private func refreshStatus() {
        guard let content = window?.contentView else { return }
        let trusted = AccessibilityHelper.isTrusted

        if let status = content.viewWithTag(100) as? NSTextField {
            status.stringValue = statusText()
            status.textColor = trusted ? .systemGreen : .secondaryLabelColor
        }
        if let button = content.viewWithTag(101) as? NSButton {
            button.isEnabled = trusted
        }
        // Hide Restart once trusted; show Continue as the path forward.
        if let restart = content.viewWithTag(103) as? NSButton {
            restart.isHidden = trusted
        }

        if trusted {
            AppDelegate.shared?.startEngineIfNeeded()
        }
    }

    @objc private func openSettings() {
        AccessibilityHelper.requestTrust(prompt: true)
        AccessibilityHelper.openSystemSettings()
    }

    @objc private func restart() {
        pollTimer?.invalidate()
        AccessibilityHelper.relaunchApp()
    }

    @objc private func finish() {
        guard AccessibilityHelper.isTrusted else { return }
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
