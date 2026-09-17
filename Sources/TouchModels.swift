/// Binary layout matching MultitouchSupport's per-touch record.
struct MTPoint {
    var x: Float
    var y: Float
}

struct MTVector {
    var position: MTPoint
    var velocity: MTPoint
}

struct MTTouch {
    var frame: Int32
    var timestamp: Double
    var pathIndex: Int32
    var state: UInt32
    var fingerID: Int32
    var handID: Int32
    var normalizedVector: MTVector
    var zTotal: Float
    var field9: Int32
    var angle: Float
    var majorAxis: Float
    var minorAxis: Float
    var absoluteVector: MTVector
    var field14: Int32
    var field15: Int32
    var zDensity: Float
}

enum TouchState {
    // Observed across MiddleClick / Trident / aerospace-swipe on modern macOS:
    // 1 notTouching, 2 hover?, 3 touching/make, 4 active, 5 break/lift edge
    static let touching: UInt32 = 3
    static let active: UInt32 = 4
    static let lifting: UInt32 = 5

    static func isContact(_ state: UInt32) -> Bool {
        state == touching || state == active || state == lifting
    }
}
