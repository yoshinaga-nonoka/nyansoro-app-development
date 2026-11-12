// 再現できる乱数（mulberry32）。同じシードなら同じ山になる（テスト・オンライン対戦の検証用）。

public struct Mulberry32: RandomNumberGenerator, Codable, Sendable, Equatable {
    public var state: UInt32

    public init(seed: UInt32) {
        state = seed
    }

    public mutating func nextUInt32() -> UInt32 {
        state = state &+ 0x6D2B_79F5
        var t = state
        t = (t ^ (t >> 15)) &* (t | 1)
        t ^= t &+ ((t ^ (t >> 7)) &* (t | 61))
        return t ^ (t >> 14)
    }

    /// 0以上1未満
    public mutating func nextUnit() -> Double {
        Double(nextUInt32()) / 4_294_967_296.0
    }

    public mutating func next() -> UInt64 {
        (UInt64(nextUInt32()) << 32) | UInt64(nextUInt32())
    }

    public mutating func shuffle<T>(_ items: [T]) -> [T] {
        var a = items
        var i = a.count - 1
        while i > 0 {
            let j = Int(nextUnit() * Double(i + 1))
            a.swapAt(i, j)
            i -= 1
        }
        return a
    }
}
