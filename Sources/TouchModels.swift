struct MTPoint {
    var x: Float
    var y: Float
}

struct MTVector {
    var position: MTPoint
    var velocity: MTPoint
}

/// Binary layout matching MultitouchSupport's per-touch record.
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
    static let touching: UInt32 = 3
    static let active: UInt32 = 4

    static func isContact(_ state: UInt32) -> Bool {
        state == touching || state == active
    }
}
