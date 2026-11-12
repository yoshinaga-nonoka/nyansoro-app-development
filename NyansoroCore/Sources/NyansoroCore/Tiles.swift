// 牌（タイル）の定義。表示用の名前は「漢字《よみ》」形式（Ruby.swift の plainText で読みを外せる）。

public struct Family: Sendable {
    public let id: String
    public let name: String
}

public enum Catalog {
    public static let families: [Family] = [
        Family(id: "mike", name: "三毛《みけ》"),
        Family(id: "kuro", name: "黒《くろ》"),
        Family(id: "shiro", name: "白《しろ》"),
        Family(id: "chatora", name: "茶《ちゃ》トラ"),
        Family(id: "sabatora", name: "サバトラ"),
        Family(id: "hachiware", name: "ハチワレ"),
    ]
    public static let roleNames: [String] = ["パパ", "ママ", "子猫《こねこ》"]
}

public let numFamilies = 6
public let numCats = 18
/// 18 = 招き猫（どの猫の代わりにもなる）
public let joker = 18
public let numKinds = 19
public let catCopies = 4
public let jokerCopies = 2
public let handSize = 8
public let totalTiles = numCats * catCopies + jokerCopies // 74

public struct Tile: Hashable, Codable, Sendable, Identifiable {
    public let id: Int
    public let kind: Int
    public init(id: Int, kind: Int) {
        self.id = id
        self.kind = kind
    }
}

public func familyOf(_ kind: Int) -> Int { kind / 3 }
public func roleOf(_ kind: Int) -> Int { kind % 3 }
public func isJoker(_ kind: Int) -> Bool { kind == joker }
public func kindCopies(_ kind: Int) -> Int { kind == joker ? jokerCopies : catCopies }
public func kindOf(_ family: Int, _ role: Int) -> Int { family * 3 + role }

public func kindName(_ kind: Int) -> String {
    if kind == joker { return "招《まね》き猫《ねこ》" }
    return "\(Catalog.families[familyOf(kind)].name)の\(Catalog.roleNames[roleOf(kind)])"
}

public func makeTiles() -> [Tile] {
    var tiles: [Tile] = []
    var id = 0
    for k in 0..<numKinds {
        for _ in 0..<kindCopies(k) {
            tiles.append(Tile(id: id, kind: k))
            id += 1
        }
    }
    return tiles
}

public func countKinds(_ tiles: [Tile]) -> [Int] {
    var counts = [Int](repeating: 0, count: numKinds)
    for t in tiles { counts[t.kind] += 1 }
    return counts
}

public func sortTiles(_ tiles: [Tile]) -> [Tile] {
    tiles.sorted { $0.kind != $1.kind ? $0.kind < $1.kind : $0.id < $1.id }
}
