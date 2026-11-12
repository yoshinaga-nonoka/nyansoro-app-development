// 上がり判定と「あと何枚」の計算。
// セットは2種類：同じ猫×3（same）／同じ家族のパパ・ママ・子猫（family）。招き猫はどの猫の代わりにもなる。

public enum SetKind: String, Codable, Sendable {
    case same
    case family
}

public struct SetType: Sendable {
    public let type: SetKind
    public let kinds: [Int]
}

public struct Need: Sendable {
    public let kind: Int
    public let count: Int
}

/// 3つのセットの組み合わせと、それに必要な牌の枚数
public struct Combo: Sendable {
    public let sets: [Int]
    public let need: [Need]
}

public let setTypes: [SetType] = {
    var list: [SetType] = []
    for k in 0..<numCats { list.append(SetType(type: .same, kinds: [k, k, k])) }
    for f in 0..<numFamilies { list.append(SetType(type: .family, kinds: [f * 3, f * 3 + 1, f * 3 + 2])) }
    return list
}()

public let combos: [Combo] = {
    var list: [Combo] = []
    let n = setTypes.count
    for i in 0..<n {
        for j in i..<n {
            for k in j..<n {
                var need = [Int: Int]()
                for s in [i, j, k] {
                    for kind in setTypes[s].kinds { need[kind, default: 0] += 1 }
                }
                // 牌の枚数より多く必要な組み合わせ（同じ猫6枚など）は作れない
                if need.contains(where: { $0.value > kindCopies($0.key) }) { continue }
                let needs = need.keys.sorted().map { Need(kind: $0, count: need[$0]!) }
                list.append(Combo(sets: [i, j, k], need: needs))
            }
        }
    }
    return list
}()

/// その組み合わせを作るのに足りない「普通の猫」の枚数
@inline(__always)
public func deficit(_ counts: [Int], _ combo: Combo) -> Int {
    var d = 0
    for n in combo.need {
        let have = counts[n.kind]
        if have < n.count { d += n.count - have }
    }
    return d
}

/// あと何枚入れ替えれば上がれるか（0 = 上がり）。9枚の手なら 0 が上がり、8枚の手なら 1 が「あと1枚」。
public func distance(_ counts: [Int]) -> Int {
    let jokers = counts[joker]
    var best = Int.max
    for c in combos {
        let d = deficit(counts, c)
        if d < best {
            best = d
            if best <= jokers { return 0 }
        }
    }
    return max(0, best - jokers)
}

/// distance(counts) < threshold かどうか（見つかった時点で打ち切るので速い）
public func distanceBelow(_ counts: [Int], _ threshold: Int) -> Bool {
    let limit = threshold + counts[joker]
    for c in combos where deficit(counts, c) < limit { return true }
    return false
}

public func isWinningHand(_ counts: [Int]) -> Bool {
    counts.reduce(0, +) == 9 && distance(counts) == 0
}

/// 8枚の手に何が来たら上がれるか（招き猫を含む）
public func waitingKinds(_ counts8: [Int]) -> [Int] {
    var c = counts8
    var out: [Int] = []
    for k in 0..<numKinds {
        if c[k] >= kindCopies(k) { continue }
        c[k] += 1
        if distance(c) == 0 { out.append(k) }
        c[k] -= 1
    }
    return out
}

public struct TileGroup: Codable, Sendable, Equatable {
    public var type: SetKind
    /// セットの3つの枠。足りない枠は nil
    public var slots: [Tile?]
    /// 枠が表す猫（招き猫で埋めた枠も元の猫）
    public var slotKinds: [Int]
    public var filled: Int { slots.compactMap { $0 }.count }
    public var complete: Bool { filled == 3 }
    public var tiles: [Tile] { slots.compactMap { $0 } }
}

public struct Arrangement: Sendable {
    public var groups: [TileGroup]
    public var leftovers: [Tile]
    public var distance: Int
}

/// 手牌を組み合わせ combo の3セットに割り当てる。足りない枠は招き猫で埋める
public func assignTiles(_ tiles: [Tile], _ combo: Combo) -> (groups: [TileGroup], leftovers: [Tile]) {
    var pools = [Int: [Tile]]()
    for t in sortTiles(tiles) { pools[t.kind, default: []].append(t) }
    var groups: [TileGroup] = combo.sets.map { si in
        let st = setTypes[si]
        var slots: [Tile?] = []
        for k in st.kinds {
            if var list = pools[k], !list.isEmpty {
                slots.append(list.removeFirst())
                pools[k] = list
            } else {
                slots.append(nil)
            }
        }
        return TileGroup(type: st.type, slots: slots, slotKinds: st.kinds)
    }
    var jokers = pools[joker] ?? []
    pools[joker] = []
    // 足りない枠が少ないセットから、招き猫で埋める
    let order = groups.indices.sorted { groups[$0].filled > groups[$1].filled }
    for gi in order {
        for s in 0..<3 where groups[gi].slots[s] == nil && !jokers.isEmpty {
            groups[gi].slots[s] = jokers.removeFirst()
        }
    }
    var leftovers = jokers
    for (_, list) in pools { leftovers.append(contentsOf: list) }
    return (groups, sortTiles(leftovers))
}

/// 手牌を「揃ったセット」「あと少しのセット」「残り」に並べ替える（ヒント表示用）
public func arrange(_ tiles: [Tile]) -> Arrangement {
    let counts = countKinds(tiles)
    let dist = distance(counts)
    let jokers = counts[joker]
    var best: (groups: [TileGroup], leftovers: [Tile], score: Int)?
    for c in combos {
        if max(0, deficit(counts, c) - jokers) != dist { continue }
        let a = assignTiles(tiles, c)
        let score = a.groups.reduce(0) { $0 + $1.filled * $1.filled }
        if best == nil || score > best!.score { best = (a.groups, a.leftovers, score) }
    }
    guard let b = best else { return Arrangement(groups: [], leftovers: sortTiles(tiles), distance: dist) }
    var groups: [TileGroup] = []
    var leftovers = b.leftovers
    for g in b.groups {
        if g.filled >= 2 { groups.append(g) } else { leftovers.append(contentsOf: g.tiles) }
    }
    groups.sort { ($0.complete ? 1 : 0) > ($1.complete ? 1 : 0) }
    return Arrangement(groups: groups, leftovers: sortTiles(leftovers), distance: dist)
}
