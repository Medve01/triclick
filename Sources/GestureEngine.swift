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
        removeTap(&clickTap, source: &runLoopSource)
        removeTap(&fnTap, source: &fnRunLoopSource)
    }

    // MARK: - Multitouch frames

    func handleTouches(_ touches: [MTTouch]) {
        let contacts = touches.filter { TouchState.isContact($0.state) }
        let count = contacts.count
        let centroid = Self.centroid(of: contacts)

        lock.lock()
        defer { lock.unlock() }

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
            return
        }

        // Fingers lift one-by-one (3→2→1→0). Keep the gesture alive until the
        // pad is clear — cancelling on the way down ate every three-finger tap.
        if gestureActive {
            if count > 0, !contacts.isEmpty {
                let dx = centroid.x - startCentroid.x
                let dy = centroid.y - startCentroid.y
                maxTravel = max(maxTravel, sqrt(dx * dx + dy * dy))
            }
            if count == 0 {
                finishTapGestureLocked()
                resetLocked()
            }
        }
    }

    private func finishTapGestureLocked() {
        guard Preferences.enabled, Preferences.threeFingerTap else { return }
        guard !emittedFromClick else { return }
        guard maxFingers == 3 else { return }
        guard shouldEmitInFrontmostApp() else { return }

        let elapsedMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        guard elapsedMs <= Double(Preferences.maxTapTimeMs) else {
            NSLog("Triclick: tap ignored — too slow (%.0f ms)", elapsedMs)
            return
        }
        guard maxTravel <= Preferences.maxTapDistance else {
            NSLog("Triclick: tap ignored — moved too far (%.3f)", maxTravel)
            return
        }

        NSLog("Triclick: three-finger tap → middle click")
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
