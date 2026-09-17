import AppKit
import Foundation

/// Owns MultitouchSupport device lifecycle and forwards frames to GestureEngine.
final class DeviceMonitor {
    static let shared = DeviceMonitor()

    private var devices: [MTDeviceRef] = []
    private var started = false
    private var wakeObserver: NSObjectProtocol?

    private init() {}

    func start() {
        guard !started else { return }
        started = true

        // Ask early — without Input Monitoring, macOS 26 delivers zero frames.
        if !AccessibilityHelper.hasInputMonitoring {
            AccessibilityHelper.requestInputMonitoring()
            NSLog("Triclick: Input Monitoring not granted — trackpad frames will be empty")
        }

        registerDevices()

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.restart()
        }
    }

    func stop() {
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
        for device in devices {
            MTUnregisterContactFrameCallback(device, contactCallback)
            if MTDeviceIsRunning(device) {
                MTDeviceStop(device)
            }
        }
        devices.removeAll()
        started = false
    }

    func restart() {
        stop()
        start()
    }

    private func registerDevices() {
        var found: [MTDeviceRef] = []

        if let list = MTDeviceCreateList()?.takeRetainedValue() {
            let count = CFArrayGetCount(list)
            for i in 0..<count {
                guard let raw = CFArrayGetValueAtIndex(list, i) else { continue }
                let device = UnsafeMutableRawPointer(mutating: raw)
                // Keep an extra retain so the framework can't tear the handle down
                // out from under us on sleep/wake (see Trident / MiddleClick lineage).
                _ = Unmanaged<AnyObject>.fromOpaque(device).retain()
                found.append(device)
            }
        }

        if found.isEmpty, let fallback = MTDeviceCreateDefault() {
            _ = Unmanaged<AnyObject>.fromOpaque(fallback).retain()
            found.append(fallback)
        }

        for device in found {
            MTRegisterContactFrameCallback(device, contactCallback)
            MTDeviceStart(device, 0)
        }
        devices = found

        NSLog("Triclick: listening on \(found.count) multitouch device(s); inputMonitoring=\(AccessibilityHelper.hasInputMonitoring)")
    }
}

private let contactCallback: MTContactCallbackFunction = { _, touches, numTouches, _, _ in
    guard let touches, numTouches > 0 else {
        GestureEngine.shared.handleTouches([])
        return 0
    }

    let buffer = UnsafeBufferPointer(
        start: touches.assumingMemoryBound(to: MTTouch.self),
        count: Int(numTouches)
    )
    GestureEngine.shared.handleTouches(Array(buffer))
    return 0
}
