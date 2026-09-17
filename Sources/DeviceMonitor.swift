import AppKit
import Foundation

/// Owns MultitouchSupport device lifecycle and forwards frames to GestureEngine.
final class DeviceMonitor {
    static let shared = DeviceMonitor()

    private var devices: [MTDeviceRef] = []
    private var started = false

    /// Magic Mouse family IDs — we skip these (trackpad-only).
    private static let magicMouseFamilies: Set<Int32> = [98, 112]

    private init() {}

    func start() {
        guard !started else { return }
        started = true
        registerDevices()

        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.restart()
        }
    }

    func stop() {
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

        if let listRef = MTDeviceCreateList()?.takeRetainedValue() {
            let count = CFArrayGetCount(listRef)
            for i in 0..<count {
                guard let raw = CFArrayGetValueAtIndex(listRef, i) else { continue }
                let device = MTDeviceRef(mutating: raw)
                let family = MTDeviceGetFamilyID(device)
                if Self.magicMouseFamilies.contains(family) {
                    continue
                }
                found.append(device)
            }
        }

        if found.isEmpty, let fallback = MTDeviceCreateDefault() {
            found.append(fallback)
        }

        for device in found {
            MTRegisterContactFrameCallback(device, contactCallback)
            MTDeviceStart(device, 0)
        }
        devices = found

        if found.isEmpty {
            NSLog("Triclick: no trackpad multitouch devices found")
        } else {
            NSLog("Triclick: listening on \(found.count) trackpad device(s)")
        }
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
