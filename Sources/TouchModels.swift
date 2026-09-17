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
    // MultitouchSupport lifecycle: 3 = make/touching, 4 = active/on-surface,
    // 5 = break/lifting. Only 3–4 mean the finger is still down.
    static let touching: UInt32 = 3
    static let active: UInt32 = 4
    static let lifting: UInt32 = 5

    static func isOnSurface(_ state: UInt32) -> Bool {
        state == touching || state == active
    }
}
