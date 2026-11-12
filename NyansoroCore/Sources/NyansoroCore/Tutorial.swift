// 練習用の決まった山。キミは3手で上がれるように並べてある。

public enum Tutorial {
    /// キミが捨てる猫（おすすめ）＝茶トラのママ
    public static let discardKind = kindOf(3, 1)
    /// CPU（1番目）が捨てて、キミが にゃん！する猫＝白の子猫
    public static let winKind = kindOf(2, 2)

    public static func deck() -> [Int] {
        let human = [kindOf(0, 0), kindOf(0, 0), kindOf(0, 0), kindOf(1, 0), kindOf(1, 1), winKind, winKind, discardKind]
        let cpu1 = [winKind, kindOf(4, 0), kindOf(5, 0), kindOf(0, 1), kindOf(1, 2), kindOf(3, 0), kindOf(4, 2), kindOf(5, 1)]
        let cpu2 = [kindOf(4, 1), kindOf(5, 2), kindOf(0, 2), kindOf(2, 0), kindOf(3, 2), kindOf(2, 1), kindOf(1, 0), kindOf(4, 2)]
        let cpu3 = [kindOf(0, 1), kindOf(3, 0), kindOf(4, 0), kindOf(5, 1), kindOf(1, 1), kindOf(3, 1), kindOf(5, 0), kindOf(4, 1)]
        let firstDraws = [kindOf(1, 2), kindOf(5, 2)]
        let head = human + cpu1 + cpu2 + cpu3 + firstDraws

        var used = [Int](repeating: 0, count: numKinds)
        for k in head { used[k] += 1 }
        var rest: [Int] = []
        for k in 0..<numKinds where used[k] < kindCopies(k) {
            rest.append(contentsOf: [Int](repeating: k, count: kindCopies(k) - used[k]))
        }
        var rng = Mulberry32(seed: 20_261_112)
        return head + rng.shuffle(rest)
    }
}
