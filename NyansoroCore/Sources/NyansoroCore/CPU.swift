// CPUの考え方（Lv1〜5）と、プレイヤー向けの「おすすめ」。
// Lv1: あと何枚が減るように（うっかり50%） / Lv2: 同じ（うっかり25%） / Lv3: 残り枚数も数える（うっかり10%）
// Lv4: 危ない猫を捨てない（うっかり3%） / Lv5: 点の高い上がりも狙う（うっかりなし）
// ※ Web版のシミュレーションでは「考え方」の差より「うっかり率」の差のほうが強さに効いた

/// レベルごとの「うっかり率」：この確率で、考えずに適当な猫を捨てる
public let mistakeRate: [Double] = [0, 0.5, 0.25, 0.1, 0.03, 0]

/// seat から見えている牌の枚数（自分の手＋全員の捨て牌）
public func visibleCounts(_ s: GameState, _ seat: Int) -> [Int] {
    var c = countKinds(s.players[seat].hand)
    for p in s.players {
        for t in p.discards { c[t.kind] += 1 }
    }
    return c
}

/// seat から見て、まだどこかに残っている枚数
public func unseenCounts(_ s: GameState, _ seat: Int) -> [Int] {
    visibleCounts(s, seat).enumerated().map { max(0, kindCopies($0.offset) - $0.element) }
}

/// 受け入れ枚数：引いたら「あと何枚」が減る牌が、残り何枚あるか
public func ukeire(_ counts: [Int], _ unseen: [Int]) -> Int {
    let base = distance(counts)
    if base == 0 { return 0 }
    var c = counts
    var sum = 0
    for k in 0..<numKinds where unseen[k] > 0 {
        c[k] += 1
        if distanceBelow(c, base) { sum += unseen[k] }
        c[k] -= 1
    }
    return sum
}

/// 他の人が上がりそうな猫かどうかの見積もり（0〜1）。相手の捨て牌だけを見る
public func dangerOf(_ s: GameState, _ seat: Int, _ kind: Int) -> Double {
    let visible = visibleCounts(s, seat)
    var total = 0.0
    for o in s.players.indices where o != seat {
        let disc = s.players[o].discards
        var d = min(1.0, 0.2 + Double(disc.count) * 0.08)
        if disc.contains(where: { $0.kind == kind }) { d *= 0.35 }
        let famDisc = disc.filter { $0.kind != joker && familyOf($0.kind) == familyOf(kind) }.count
        if famDisc >= 2 { d *= 0.55 } else if famDisc == 1 { d *= 0.8 }
        total += d
    }
    if visible[kind] >= 3 { total *= 0.6 }
    return total / Double(s.players.count - 1)
}

/// 「全部同じ」「全部家族」を狙える形が残っているか
func purityOf(_ counts: [Int], _ dist: Int) -> Double {
    let jokers = counts[joker]
    for c in combos where max(0, deficit(counts, c) - jokers) == dist {
        let types = c.sets.map { setTypes[$0].type }
        if types.allSatisfy({ $0 == types[0] }) { return 1 }
    }
    return 0
}

public struct DiscardOption: Sendable {
    public let kind: Int
    public let dist: Int
    public let ukeire: Int
    public let danger: Double
    public let purity: Double
}

public func discardOptions(_ s: GameState, _ seat: Int, ukeire withUkeire: Bool = false, danger withDanger: Bool = false, purity withPurity: Bool = false) -> [DiscardOption] {
    var counts = countKinds(s.players[seat].hand)
    let unseen = withUkeire ? unseenCounts(s, seat) : []
    var out: [DiscardOption] = []
    for k in 0..<numKinds where counts[k] > 0 && k != joker {
        counts[k] -= 1
        let dist = distance(counts)
        out.append(DiscardOption(
            kind: k,
            dist: dist,
            ukeire: withUkeire ? ukeire(counts, unseen) : 0,
            danger: withDanger ? dangerOf(s, seat, k) : 0,
            purity: withPurity ? purityOf(counts, dist) : 0
        ))
        counts[k] += 1
    }
    return out
}

private func dangerWeight(_ dist: Int, _ penalty: Int) -> Double {
    let base: Double = dist <= 1 ? 20 : dist == 2 ? 55 : 110
    return base * (1 + Double(penalty) / 10)
}

private func pickTile(_ s: GameState, _ seat: Int, kind: Int) -> Int {
    let hand = s.players[seat].hand
    return hand.last(where: { $0.kind == kind })!.id
}

/// CPUが捨てる牌の id を決める
public func chooseDiscard(_ s: GameState, _ seat: Int, level: Int, rand: () -> Double = { Double.random(in: 0..<1) }) -> Int {
    let normal = s.players[seat].hand.filter { $0.kind != joker }
    let rate = level < mistakeRate.count ? mistakeRate[level] : 0
    if rand() < rate {
        return normal[min(normal.count - 1, Int(rand() * Double(normal.count)))].id
    }
    if level <= 2 {
        let opts = discardOptions(s, seat)
        let best = opts.map(\.dist).min()!
        let pool = opts.filter { $0.dist == best }
        return pickTile(s, seat, kind: pool[min(pool.count - 1, Int(rand() * Double(pool.count)))].kind)
    }
    let opts = discardOptions(s, seat, ukeire: true, danger: level >= 4, purity: level >= 5)
    var bestKind = opts[0].kind
    var bestScore = -Double.infinity
    for o in opts {
        var score = -Double(o.dist) * 100 + Double(o.ukeire) * 2 + rand() * 0.5
        if level >= 4 { score -= o.danger * dangerWeight(o.dist, s.rules.furikomiPenalty) }
        if level >= 5 { score += o.purity * 12 }
        if score > bestScore {
            bestScore = score
            bestKind = o.kind
        }
    }
    return pickTile(s, seat, kind: bestKind)
}

/// プレイヤーへの「おすすめ」（Lv3と同じ考え方。乱数なし）
public func recommendDiscard(_ s: GameState, _ seat: Int) -> Int? {
    let counts = countKinds(s.players[seat].hand)
    let opts = discardOptions(s, seat, ukeire: true).sorted { a, b in
        if a.dist != b.dist { return a.dist < b.dist }
        if a.ukeire != b.ukeire { return a.ukeire > b.ukeire }
        if counts[a.kind] != counts[b.kind] { return counts[a.kind] < counts[b.kind] }
        return a.kind > b.kind
    }
    return opts.first?.kind
}

/// プレイヤーの手の「今の状態」：あと何枚・待っている猫・おすすめ
public struct Insight: Sendable, Equatable {
    public let canWin: Bool
    public let dist: Int
    public let waits: [Int]
    public let rec: Int?
    public let afterDiscard: Bool
    public let unseen: [Int]
}

public func handInsight(_ s: GameState, seat: Int, recommendOn: Bool) -> Insight? {
    let hand = s.players[seat].hand
    guard (8...9).contains(hand.count), s.phase != .roundEnd, s.phase != .matchEnd else { return nil }
    var counts = countKinds(hand)
    let unseen = unseenCounts(s, seat)
    if hand.count == 9 {
        if canWin(hand) { return Insight(canWin: true, dist: 0, waits: [], rec: nil, afterDiscard: false, unseen: unseen) }
        if recommendOn, let rec = recommendDiscard(s, seat) {
            counts[rec] -= 1
            let dist = distance(counts)
            return Insight(canWin: false, dist: dist, waits: dist == 1 ? waitingKinds(counts) : [], rec: rec, afterDiscard: true, unseen: unseen)
        }
        return Insight(canWin: false, dist: distance(counts), waits: [], rec: nil, afterDiscard: false, unseen: unseen)
    }
    let dist = distance(counts)
    return Insight(canWin: false, dist: dist, waits: dist == 1 ? waitingKinds(counts) : [], rec: nil, afterDiscard: false, unseen: unseen)
}
