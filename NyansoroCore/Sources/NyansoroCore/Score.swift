// 点数計算。上がった人だけが点をもらう（上のランクでは「上がり牌を捨てた人は −5」）。
// 「役」＝上がり方や揃え方のボーナス。いくつでも重ねられる。

public struct ScoreItem: Codable, Sendable, Equatable, Hashable {
    public let label: String
    public let points: Int
}

public struct WinInfo: Codable, Sendable, Equatable {
    public let total: Int
    public let items: [ScoreItem]
    public let groups: [TileGroup]
}

/// 上がったときの状況（手の形以外で点数が変わるもの）
public struct WinContext: Sendable, Equatable {
    /// 自分で引いて上がった
    public var tsumo: Bool
    /// リーチしていた
    public var riichi: Bool
    /// リーチしてから、次に自分が捨てるまでに上がった
    public var ippatsu: Bool
    /// 山の最後の1枚（または最後に捨てられた猫）で上がった
    public var lastTile: Bool

    public init(tsumo: Bool, riichi: Bool = false, ippatsu: Bool = false, lastTile: Bool = false) {
        self.tsumo = tsumo
        self.riichi = riichi
        self.ippatsu = ippatsu
        self.lastTile = lastTile
    }
}

/// 役の説明（遊び方・上達レッスン用）
public struct ScoreRule: Sendable, Identifiable {
    public var id: String { item.label }
    public let item: ScoreItem
    public let detail: String
    /// 例の手（9枚。空なら例なし）
    public let example: [Int]
}

public enum ScoreTable {
    public static let base = ScoreItem(label: "上《あ》がり", points: 10)
    public static let tsumo = ScoreItem(label: "自分《じぶん》で引《ひ》いて上《あ》がり", points: 5)
    public static let riichi = ScoreItem(label: "リーチ", points: 10)
    public static let ippatsu = ScoreItem(label: "すぐにゃん", points: 5)
    public static let noJoker = ScoreItem(label: "招《まね》き猫《ねこ》なし", points: 5)
    public static let allSame = ScoreItem(label: "全部《ぜんぶ》同《おな》じ猫《ねこ》", points: 10)
    public static let allFamily = ScoreItem(label: "全部《ぜんぶ》家族《かぞく》", points: 10)
    public static let familyAndSiblings = ScoreItem(label: "家族《かぞく》と兄弟《きょうだい》", points: 5)
    public static let lastTile = ScoreItem(label: "最後《さいご》の1枚《まい》", points: 10)
    public static let rolePapa = ScoreItem(label: "パパそろい", points: 15)
    public static let roleMama = ScoreItem(label: "ママそろい", points: 15)
    public static let roleKitten = ScoreItem(label: "子猫《こねこ》そろい", points: 15)
    public static let oneFamily = ScoreItem(label: "ひと家族《かぞく》だらけ", points: 20)

    public static let roleItems = [rolePapa, roleMama, roleKitten]

    /// 点数表（表示の順番）
    public static let all: [ScoreItem] = [base, tsumo, riichi, ippatsu, noJoker, allSame, allFamily, familyAndSiblings, lastTile, rolePapa, roleMama, roleKitten, oneFamily]

    /// 役の一覧と説明（例の手つき）
    public static let rules: [ScoreRule] = [
        ScoreRule(item: base, detail: "9枚《まい》で3枚《まい》セットを3つ作《つく》ったら、まず10点《てん》。", example: []),
        ScoreRule(item: tsumo, detail: "山《やま》から引《ひ》いた猫《ねこ》で揃《そろ》ったとき。", example: []),
        ScoreRule(item: riichi, detail: "あと1枚《まい》になったときに「リーチ」と言《い》って捨《す》てる。そのあとは手《て》を変《か》えられないけど、上《あ》がれば +10点《てん》。", example: []),
        ScoreRule(item: ippatsu, detail: "リーチしてから、次《つぎ》に自分《じぶん》が捨《す》てる前《まえ》に上《あ》がる。", example: []),
        ScoreRule(item: noJoker, detail: "招《まね》き猫《ねこ》を使《つか》わずに揃《そろ》える。", example: []),
        ScoreRule(item: allSame, detail: "3組《くみ》とも同《おな》じ猫《ねこ》3枚《まい》。", example: [kindOf(0, 0), kindOf(0, 0), kindOf(0, 0), kindOf(2, 1), kindOf(2, 1), kindOf(2, 1), kindOf(4, 2), kindOf(4, 2), kindOf(4, 2)]),
        ScoreRule(item: allFamily, detail: "3組《くみ》ともパパ・ママ・子猫《こねこ》の家族《かぞく》セット。", example: [kindOf(1, 0), kindOf(1, 1), kindOf(1, 2), kindOf(3, 0), kindOf(3, 1), kindOf(3, 2), kindOf(5, 0), kindOf(5, 1), kindOf(5, 2)]),
        ScoreRule(item: familyAndSiblings, detail: "同《おな》じ家族《かぞく》で「家族《かぞく》セット」と「同《おな》じ猫《ねこ》3枚《まい》」の両方《りょうほう》がある。", example: [kindOf(0, 0), kindOf(0, 1), kindOf(0, 2), kindOf(0, 1), kindOf(0, 1), kindOf(0, 1), kindOf(4, 0), kindOf(4, 1), kindOf(4, 2)]),
        ScoreRule(item: lastTile, detail: "山《やま》の最後《さいご》の1枚《まい》か、最後《さいご》に捨《す》てられた猫《ねこ》で上《あ》がる。", example: []),
        ScoreRule(item: rolePapa, detail: "3組《くみ》とも、パパ3枚《まい》のセット（ママそろい・子猫《こねこ》そろいも同《おな》じ +15点《てん》）。", example: [kindOf(0, 0), kindOf(0, 0), kindOf(0, 0), kindOf(1, 0), kindOf(1, 0), kindOf(1, 0), kindOf(5, 0), kindOf(5, 0), kindOf(5, 0)]),
        ScoreRule(item: oneFamily, detail: "9枚《まい》が全部《ぜんぶ》同《おな》じ家族《かぞく》。めったに出《で》ない大物《おおもの》！", example: [kindOf(2, 0), kindOf(2, 0), kindOf(2, 0), kindOf(2, 1), kindOf(2, 1), kindOf(2, 1), kindOf(2, 2), kindOf(2, 2), kindOf(2, 2)]),
    ]

    /// 揃え方で付く役（上がり方で付く役は含まない）
    static func shapeItems(_ combo: Combo) -> [ScoreItem] {
        let sets = combo.sets.map { setTypes[$0] }
        var items: [ScoreItem] = []
        if sets.allSatisfy({ $0.type == .same }) {
            items.append(allSame)
            let roles = Set(sets.map { roleOf($0.kinds[0]) })
            if roles.count == 1 { items.append(roleItems[roles.first!]) }
        }
        if sets.allSatisfy({ $0.type == .family }) { items.append(allFamily) }
        let families = sets.filter { $0.type == .family }.map { familyOf($0.kinds[0]) }
        let sameFamilies = sets.filter { $0.type == .same }.map { familyOf($0.kinds[0]) }
        if families.contains(where: { sameFamilies.contains($0) }) { items.append(familyAndSiblings) }
        if Set(sets.map { familyOf($0.kinds[0]) }).count == 1 { items.append(oneFamily) }
        return items
    }
}

/// 9枚の手が上がりなら、一番点が高くなる分け方で点数を返す
public func scoreWin(_ tiles: [Tile], _ ctx: WinContext) -> WinInfo? {
    let counts = countKinds(tiles)
    guard counts.reduce(0, +) == 9 else { return nil }
    let jokers = counts[joker]
    var situation: [ScoreItem] = [ScoreTable.base]
    if ctx.tsumo { situation.append(ScoreTable.tsumo) }
    if ctx.riichi { situation.append(ScoreTable.riichi) }
    if ctx.riichi, ctx.ippatsu { situation.append(ScoreTable.ippatsu) }
    if ctx.lastTile { situation.append(ScoreTable.lastTile) }
    if jokers == 0 { situation.append(ScoreTable.noJoker) }
    var best: WinInfo?
    for c in combos {
        if deficit(counts, c) > jokers { continue }
        let items = situation + ScoreTable.shapeItems(c)
        let total = items.reduce(0) { $0 + $1.points }
        if best == nil || total > best!.total {
            best = WinInfo(total: total, items: items, groups: assignTiles(tiles, c).groups)
        }
    }
    return best
}

public func scoreWin(_ tiles: [Tile], tsumo: Bool) -> WinInfo? {
    scoreWin(tiles, WinContext(tsumo: tsumo))
}
