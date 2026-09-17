import AppKit

final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private weak var appDelegate: AppDelegate?

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.image = Self.menuIcon()
            button.imagePosition = .imageOnly
            button.toolTip = "Triclick"
        }

        statusItem.menu = buildMenu()
    }

    func reload() {
        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        if !AccessibilityHelper.isTrusted {
            let warn = NSMenuItem(title: "Needs Accessibility Permission…", action: #selector(showOnboarding), keyEquivalent: "")
            warn.target = self
            menu.addItem(warn)
            menu.addItem(.separator())
        }

        menu.addItem(toggleItem(
            title: Preferences.enabled ? "Enabled" : "Disabled",
            state: Preferences.enabled,
            action: #selector(toggleEnabled)
        ))

        menu.addItem(.separator())

        let trackpad = NSMenuItem(title: "Trackpad", action: nil, keyEquivalent: "")
        trackpad.isEnabled = false
        menu.addItem(trackpad)

        menu.addItem(toggleItem(
            title: "Three-Finger Click",
            state: Preferences.threeFingerClick,
            action: #selector(toggleClick),
            indent: 1
        ))
        menu.addItem(toggleItem(
            title: "Three-Finger Tap",
            state: Preferences.threeFingerTap,
            action: #selector(toggleTap),
            indent: 1
        ))

        menu.addItem(.separator())

        menu.addItem(toggleItem(
            title: "fn + Click",
            state: Preferences.fnClick,
            action: #selector(toggleFn)
        ))
        menu.addItem(toggleItem(
            title: "Launch at Login",
            state: LoginItem.isEnabled || Preferences.launchAtLogin,
            action: #selector(toggleLogin)
        ))

        menu.addItem(.separator())

        let ignore = NSMenuItem(title: "Ignore Current App", action: #selector(ignoreCurrentApp), keyEquivalent: "")
        ignore.target = self
        if let name = NSWorkspace.shared.frontmostApplication?.localizedName {
            ignore.title = "Ignore \(name)"
        }
        menu.addItem(ignore)

        if !Preferences.ignoredApps.isEmpty {
            let clear = NSMenuItem(title: "Clear Ignored Apps", action: #selector(clearIgnored), keyEquivalent: "")
            clear.target = self
            menu.addItem(clear)
        }

        menu.addItem(.separator())

        let about = NSMenuItem(title: "About Triclick", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let quit = NSMenuItem(title: "Quit Triclick", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        return menu
    }

    private func toggleItem(title: String, state: Bool, action: Selector, indent: Int = 0) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.state = state ? .on : .off
        item.indentationLevel = indent
        return item
    }

    @objc private func toggleEnabled() {
        Preferences.enabled.toggle()
        reload()
    }

    @objc private func toggleClick() {
        Preferences.threeFingerClick.toggle()
        reload()
    }

    @objc private func toggleTap() {
        Preferences.threeFingerTap.toggle()
        reload()
    }

    @objc private func toggleFn() {
        Preferences.fnClick.toggle()
        reload()
    }

    @objc private func toggleLogin() {
        let next = !LoginItem.isEnabled
        LoginItem.setEnabled(next)
        reload()
    }

    @objc private func ignoreCurrentApp() {
        guard let id = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return }
        var set = Preferences.ignoredApps
        set.insert(id)
        Preferences.ignoredApps = set
        reload()
    }

    @objc private func clearIgnored() {
        Preferences.ignoredApps = []
        reload()
    }

    @objc private func showOnboarding() {
        OnboardingController.shared.show()
    }

    @objc private func showAbout() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let alert = NSAlert()
        alert.messageText = "Triclick"
        alert.informativeText = "Version \(version)\n\nThree fingers. Middle click.\n\nOpen source · MIT License"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "GitHub")
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            if let url = URL(string: "https://github.com/Medve01/triclick") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    /// Template menu-bar glyph: three dots over a click line.
    private static func menuIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let dot: CGFloat = 2.4
            let yDots = rect.midY + 2.5
            let spacing: CGFloat = 4.2
            let xs = [rect.midX - spacing, rect.midX, rect.midX + spacing]
            NSColor.black.setFill()
            for x in xs {
                let r = NSRect(x: x - dot / 2, y: yDots - dot / 2, width: dot, height: dot)
                NSBezierPath(ovalIn: r).fill()
            }
            let line = NSBezierPath()
            line.lineWidth = 1.4
            line.move(to: NSPoint(x: rect.midX - 5.5, y: rect.midY - 4))
            line.line(to: NSPoint(x: rect.midX + 5.5, y: rect.midY - 4))
            NSColor.black.setStroke()
            line.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }
}
