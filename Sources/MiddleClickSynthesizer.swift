import AppKit
import CoreGraphics

enum MiddleClickSynthesizer {
    private static let mouseSource = CGEventSource(stateID: .privateState)

    static func postClick() {
        guard let location = CGEvent(source: nil)?.location else { return }
        post(type: .otherMouseDown, at: location)
        post(type: .otherMouseUp, at: location)
    }

    private static func post(type: CGEventType, at location: CGPoint) {
        guard let event = CGEvent(
            mouseEventSource: mouseSource,
            mouseType: type,
            mouseCursorPosition: location,
            mouseButton: .center
        ) else { return }
        event.setIntegerValueField(.mouseEventButtonNumber, value: 2)
        event.flags = []
        event.post(tap: .cghidEventTap)
    }
}
