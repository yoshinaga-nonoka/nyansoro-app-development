// 練習（チュートリアルタスク）用の決まった山。
// 1. basics：キミは3手で上がれるように並べてある（同じ猫3枚・家族セット・人の捨てた猫で上がる）
// 2. riichi：あと1枚になったらリーチ → 次に引いた猫で上がる（リーチ＋すぐにゃん）
// 3. yaku：家族セットを3つ作って「全部家族」の役で点数を上げる
// 山から引く順番は決まっている（4人が順に1枚ずつ引くので、キミは 0, 4, 8… 枚目を引く）。

public enum TutorialTask: String, CaseIterable, Codable, Sendable, Identifiable {
    case basics, riichi, yaku

    public var id: String { rawValue }

    /// 練習の名前
    public var title: String {
        switch self {
        case .basics: return "3枚《まい》セットで上《あ》がってみよう"
        case .riichi: return "リーチして上《あ》がろう"
        case .yaku: return "役《やく》を作《つく》って点数《てんすう》を上《あ》げよう"
        }
    }

    /// 何を覚えるか
    public var goal: String {
        switch self {
        case .basics: return "同《おな》じ猫《ねこ》3枚《まい》と、家族《かぞく》セットを作《つく》って、にゃん！で上《あ》がる。"
        case .riichi: return "あと1枚《まい》になったら「リーチ」。上《あ》がると +10点《てん》。"
        case .yaku: return "家族《かぞく》セットを3つ揃《そろ》えて「全部《ぜんぶ》家族《かぞく》」+10点《てん》。"
        }
    }

    public var next: TutorialTask? {
        let all = TutorialTask.allCases
        let i = all.firstIndex(of: self)!
        return i + 1 < all.count ? all[i + 1] : nil
    }

    /// 練習が成功したか（キミ＝席0）
    public func isCleared(_ r: RoundResult?) -> Bool {
        guard let r, r.winner == 0, let win = r.win else { return false }
        switch self {
        case .basics: return true
        case .riichi: return win.items.contains(ScoreTable.riichi)
        case .yaku: return win.items.contains(ScoreTable.allFamily)
        }
    }

    /// キミが捨てる猫（肉球マークのおすすめ）。順番どおり
    public var discardKinds: [Int] {
        switch self {
        case .basics: return [Tutorial.discardKind]
        case .riichi: return [kindOf(0, 2)]
        case .yaku: return [kindOf(4, 2), kindOf(1, 2)]
        }
    }

    public func deck() -> [Int] {
        switch self {
        case .basics:
            return Tutorial.deck()
        case .riichi:
            // サバトラのママ×3、ハチワレのパパ・子猫、茶トラのパパ×2、三毛の子猫
            // 1枚目：ハチワレのママ（家族セット完成）→ 三毛の子猫を捨ててリーチ → 2枚目：茶トラのパパで上がり
            return Tutorial.build(
                human: [kindOf(4, 1), kindOf(4, 1), kindOf(4, 1), kindOf(5, 0), kindOf(5, 2), kindOf(3, 0), kindOf(3, 0), kindOf(0, 2)],
                draws: [kindOf(5, 1), kindOf(3, 0)],
                seed: 20_261_201
            )
        case .yaku:
            // 三毛の家族、白のパパ・ママ、サバトラのパパ・子猫・子猫
            // 1枚目：白の子猫 → サバトラの子猫を捨てる（家族セット狙い）→ 2枚目：黒の子猫（捨てる）→ 3枚目：サバトラのママで全部家族
            return Tutorial.build(
                human: [kindOf(0, 0), kindOf(0, 1), kindOf(0, 2), kindOf(2, 0), kindOf(2, 1), kindOf(4, 0), kindOf(4, 2), kindOf(4, 2)],
                draws: [kindOf(2, 2), kindOf(1, 2), kindOf(4, 1)],
                seed: 20_261_202
            )
        }
    }
}

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

    /// キミの手（8枚）と、キミが引く猫（順番どおり）から山を作る。
    /// 残りは混ぜて CPU の手と山にする。キミの上がり牌（draws の最後の猫）と招き猫は、
    /// CPU が先に捨てないように山の後ろへ回す。
    public static func build(human: [Int], draws: [Int], seed: UInt32) -> [Int] {
        var used = [Int](repeating: 0, count: numKinds)
        for k in human + draws { used[k] += 1 }
        var rest: [Int] = []
        for k in 0..<numKinds where used[k] < kindCopies(k) {
            rest.append(contentsOf: [Int](repeating: k, count: kindCopies(k) - used[k]))
        }
        var rng = Mulberry32(seed: seed)
        rest = rng.shuffle(rest)
        let late: Set<Int> = [draws.last ?? joker, joker]
        rest = rest.filter { !late.contains($0) } + rest.filter { late.contains($0) }
        // CPU の手（24枚）を先に取り、そのあと山。キミは山の 0, 4, 8… 枚目を引く
        var deck = human + Array(rest.prefix(24))
        var others = Array(rest.dropFirst(24))
        var wall: [Int] = []
        var i = 0
        var di = 0
        while di < draws.count || !others.isEmpty {
            if i % seats == 0, di < draws.count {
                wall.append(draws[di])
                di += 1
            } else if !others.isEmpty {
                wall.append(others.removeFirst())
            }
            i += 1
        }
        deck += wall
        return deck
    }
}
