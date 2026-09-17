import AppKit
import CoreGraphics

enum MiddleClickSynthesizer {
    private static let mouseSource: CGEventSource? = {
        let source = CGEventSource(stateID: .combinedSessionState)
        source?.localEventsSuppressionInterval = 0
        return source
    }()

    static func postClick() {
        let location = CGEvent(source: nil)?.location ?? .zero
        guard location != .zero || NSEvent.mouseLocation.x != 0 else {
            // Fall back to Cocoa mouse location (AppKit / Cocoa coords flipped).
            postAtCocoaPoint(NSEvent.mouseLocation)
            return
        }
        postDownUp(at: location)
    }

    private static func postAtCocoaPoint(_ cocoa: NSPoint) {
        // CGEvent wants quartz global coords: y=0 at top-left of main display.
        guard let screen = NSScreen.main else {
            postDownUp(at: CGPoint(x: cocoa.x, y: cocoa.y))
            return
        }
        let height = screen.frame.height
        let quartz = CGPoint(x: cocoa.x, y: height - cocoa.y)
        postDownUp(at: quartz)
    }

    private static func postDownUp(at location: CGPoint) {
        guard
            let down = CGEvent(
                mouseEventSource: mouseSource,
                mouseType: .otherMouseDown,
                mouseCursorPosition: location,
                mouseButton: .center
            ),
            let up = CGEvent(
                mouseEventSource: mouseSource,
                mouseType: .otherMouseUp,
                mouseCursorPosition: location,
                mouseButton: .center
            )
        else {
            NSLog("Triclick: failed to create middle-click CGEvent")
            return
        }

        for event in [down, up] {
            event.setIntegerValueField(.mouseEventButtonNumber, value: 2)
            event.setIntegerValueField(.mouseEventClickState, value: 1)
            event.flags = []
            event.post(tap: .cghidEventTap)
        }
        NSLog("Triclick: posted middle click at (%.0f, %.0f)", location.x, location.y)
    }
}
