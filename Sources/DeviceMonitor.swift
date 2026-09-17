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
        // Prefer the default (built-in) trackpad. Iterating MTDeviceCreateList and
        // calling family APIs on raw CFArray pointers is crash-prone across OS versions.
        var found: [MTDeviceRef] = []

        if let device = MTDeviceCreateDefault() {
            found.append(device)
        }

        for device in found {
            MTRegisterContactFrameCallback(device, contactCallback)
            MTDeviceStart(device, 0)
        }
        devices = found

        if found.isEmpty {
            NSLog("Triclick: no trackpad multitouch device found")
        } else {
            NSLog("Triclick: listening on built-in trackpad")
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
