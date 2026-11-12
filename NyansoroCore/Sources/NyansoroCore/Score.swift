// 点数計算。上がった人だけが点をもらう（上のランクでは「上がり牌を捨てた人は −5」）。

public struct ScoreItem: Codable, Sendable, Equatable, Hashable {
    public let label: String
    public let points: Int
}

public struct WinInfo: Codable, Sendable, Equatable {
    public let total: Int
    public let items: [ScoreItem]
    public let groups: [TileGroup]
}

public enum ScoreTable {
    public static let base = ScoreItem(label: "上《あ》がり", points: 10)
    public static let tsumo = ScoreItem(label: "自分《じぶん》で引《ひ》いて上《あ》がり", points: 5)
    public static let noJoker = ScoreItem(label: "招《まね》き猫《ねこ》なし", points: 5)
    public static let allSame = ScoreItem(label: "全部《ぜんぶ》同《おな》じ猫《ねこ》", points: 10)
    public static let allFamily = ScoreItem(label: "全部《ぜんぶ》家族《かぞく》", points: 10)
    public static let all: [ScoreItem] = [base, tsumo, noJoker, allSame, allFamily]
}

/// 9枚の手が上がりなら、一番点が高くなる分け方で点数を返す
public func scoreWin(_ tiles: [Tile], tsumo: Bool) -> WinInfo? {
    let counts = countKinds(tiles)
    guard counts.reduce(0, +) == 9 else { return nil }
    let jokers = counts[joker]
    var best: WinInfo?
    for c in combos {
        if deficit(counts, c) > jokers { continue }
        let types = c.sets.map { setTypes[$0].type }
        var items: [ScoreItem] = [ScoreTable.base]
        if tsumo { items.append(ScoreTable.tsumo) }
        if jokers == 0 { items.append(ScoreTable.noJoker) }
        if types.allSatisfy({ $0 == .same }) { items.append(ScoreTable.allSame) }
        if types.allSatisfy({ $0 == .family }) { items.append(ScoreTable.allFamily) }
        let total = items.reduce(0) { $0 + $1.points }
        if best == nil || total > best!.total {
            best = WinInfo(total: total, items: items, groups: assignTiles(tiles, c).groups)
        }
    }
    return best
}
