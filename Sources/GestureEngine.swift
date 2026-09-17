import AppKit
import Foundation

/// Recognizes three-finger tap / click on the trackpad and optional fn+click.
final class GestureEngine {
    static let shared = GestureEngine()

    private let lock = NSLock()
    private var contactCount: Int = 0
    private var gestureActive = false
    private var startTime: CFAbsoluteTime = 0
    private var startCentroid = MTPoint(x: 0, y: 0)
    private var maxFingers = 0
    private var maxTravel: Float = 0
    private var emittedFromClick = false

    private var clickTap: CFMachPort?
    private var fnTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var fnRunLoopSource: CFRunLoopSource?
    private var liftWatchdog: DispatchWorkItem?

    private init() {}

    var currentContactCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return contactCount
    }

    func start() {
        installClickTap()
        installFnTap()
    }

    func stop() {
        liftWatchdog?.cancel()
        liftWatchdog = nil
        removeTap(&clickTap, source: &runLoopSource)
        removeTap(&fnTap, source: &fnRunLoopSource)
    }

    // MARK: - Multitouch frames

    func handleTouches(_ touches: [MTTouch]) {
        // States 3–4 = on surface. Exclude 5 (break): counting it kept the chord
        // "alive" until frames stopped entirely, so we never saw a falling edge.
        let contacts = touches.filter { TouchState.isOnSurface($0.state) }
        let count = contacts.count
        let centroid = Self.centroid(of: contacts)

        var armWatchdog = false
        var fireTap = false

        lock.lock()
        let previous = contactCount
        contactCount = count

        if count >= 3 {
            if !gestureActive {
                gestureActive = true
                startTime = CFAbsoluteTimeGetCurrent()
                startCentroid = centroid
                maxFingers = count
                maxTravel = 0
                emittedFromClick = false
            } else {
                maxFingers = max(maxFingers, count)
                let dx = centroid.x - startCentroid.x
                let dy = centroid.y - startCentroid.y
                maxTravel = max(maxTravel, sqrt(dx * dx + dy * dy))
            }
            armWatchdog = true
        } else if gestureActive, previous >= 3 {
            // Chord just broke (3→2 / 3→0) — this is a tap.
            fireTap = true
            finishTapGestureLocked()
            resetLocked()
        } else if gestureActive, count == 0 {
            resetLocked()
        }
        lock.unlock()

        // Multitouch often stops delivering frames on lift while still reporting
        // 3 contacts on the last frame. If we go quiet for ~50ms mid-chord, treat
        // that as a release so taps still register.
        DispatchQueue.main.async {
            self.liftWatchdog?.cancel()
            self.liftWatchdog = nil
            guard armWatchdog, !fireTap else { return }
            let work = DispatchWorkItem { [weak self] in
                self?.handleSilentLift()
            }
            self.liftWatchdog = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
        }
    }

    private func handleSilentLift() {
        lock.lock()
        defer { lock.unlock() }
        guard gestureActive, contactCount >= 3 else { return }
        NSLog("Triclick: silent lift watchdog (was %d fingers)", contactCount)
        contactCount = 0
        finishTapGestureLocked()
        resetLocked()
    }

    private func finishTapGestureLocked() {
        guard Preferences.enabled, Preferences.threeFingerTap else { return }
        guard !emittedFromClick else {
            NSLog("Triclick: tap skipped — already handled as three-finger click")
            return
        }
        guard maxFingers >= 3, maxFingers <= 4 else { return }
        guard shouldEmitInFrontmostApp() else { return }

        let elapsedMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        // Ignore hair-trigger noise and long rests / drags.
        guard elapsedMs >= 25 else { return }
        guard elapsedMs <= Double(Preferences.maxTapTimeMs) else {
            NSLog("Triclick: tap ignored — too slow (%.0f ms)", elapsedMs)
            return
        }
        guard maxTravel <= Preferences.maxTapDistance else {
            NSLog("Triclick: tap ignored — moved too far (%.3f)", maxTravel)
            return
        }

        NSLog("Triclick: three-finger tap → middle click (fingers=%d travel=%.3f %.0fms)", maxFingers, maxTravel, elapsedMs)
        DispatchQueue.main.async {
            MiddleClickSynthesizer.postClick()
        }
    }

    private func resetLocked() {
        gestureActive = false
        maxFingers = 0
        maxTravel = 0
        emittedFromClick = false
    }

    // MARK: - Physical three-finger click (convert left-click)

    private func installClickTap() {
        removeTap(&clickTap, source: &runLoopSource)

        let mask = (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.leftMouseUp.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                let engine = Unmanaged<GestureEngine>.fromOpaque(refcon!).takeUnretainedValue()
                return engine.handleMouseEvent(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            NSLog("Triclick: failed to create mouse event tap — is Accessibility granted?")
            return
        }

        clickTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handleMouseEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = clickTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard Preferences.enabled, Preferences.threeFingerClick else {
            return Unmanaged.passUnretained(event)
        }
        guard shouldEmitInFrontmostApp() else {
            return Unmanaged.passUnretained(event)
        }

        lock.lock()
        let fingers = contactCount
        let tracking = gestureActive && maxFingers == 3
        lock.unlock()

        guard fingers == 3, tracking else {
            return Unmanaged.passUnretained(event)
        }

        if type == .leftMouseDown {
            lock.lock()
            emittedFromClick = true
            lock.unlock()
            MiddleClickSynthesizer.postClick()
            return nil // swallow the left click
        }

        if type == .leftMouseUp {
            // Swallow the matching up so apps don't see a dangling left-up.
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    // MARK: - fn + click

    private func installFnTap() {
        removeTap(&fnTap, source: &fnRunLoopSource)

        let mask = (1 << CGEventType.leftMouseDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                let engine = Unmanaged<GestureEngine>.fromOpaque(refcon!).takeUnretainedValue()
                return engine.handleFnClick(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return
        }

        fnTap = tap
        fnRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), fnRunLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handleFnClick(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = fnTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard Preferences.enabled, Preferences.fnClick else {
            return Unmanaged.passUnretained(event)
        }
        guard shouldEmitInFrontmostApp() else {
            return Unmanaged.passUnretained(event)
        }

        // fn key appears as .maskSecondaryFn on modern Macs.
        let flags = event.flags
        guard flags.contains(.maskSecondaryFn) else {
            return Unmanaged.passUnretained(event)
        }

        // Don't double-fire with three-finger click path.
        lock.lock()
        let fingers = contactCount
        lock.unlock()
        if fingers >= 3 { return Unmanaged.passUnretained(event) }

        MiddleClickSynthesizer.postClick()
        return nil
    }

    // MARK: - Helpers

    private func shouldEmitInFrontmostApp() -> Bool {
        let ignored = Preferences.ignoredApps
        guard !ignored.isEmpty else { return true }
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
            return true
        }
        return !ignored.contains(bundleID)
    }

    private func removeTap(_ tap: inout CFMachPort?, source: inout CFRunLoopSource?) {
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        tap = nil
        source = nil
    }

    private static func centroid(of touches: [MTTouch]) -> MTPoint {
        guard !touches.isEmpty else { return MTPoint(x: 0, y: 0) }
        var x: Float = 0
        var y: Float = 0
        for touch in touches {
            x += touch.normalizedVector.position.x
            y += touch.normalizedVector.position.y
        }
        let n = Float(touches.count)
        return MTPoint(x: x / n, y: y / n)
    }
}
