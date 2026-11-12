// CPU対戦のランク。★を貯めるとランクアップ（ランクは下がらない）。

public enum MatId: String, Codable, Sendable, CaseIterable {
    case ramune, ichigo, matcha, yozora, hachimitsu

    public var name: String {
        switch self {
        case .ramune: return "ラムネ"
        case .ichigo: return "苺《いちご》ミルク"
        case .matcha: return "抹茶《まっちゃ》ミルク"
        case .yozora: return "夜空《よぞら》"
        case .hachimitsu: return "蜂蜜《はちみつ》"
        }
    }
}

public struct CpuDef: Sendable {
    public let name: String
    public let avatar: Int
}

public struct RankDef: Sendable {
    public let id: String
    public let name: String
    public let level: Int
    public let starsToNext: Int
    public let furikomiPenalty: Int
    /// おすすめ（肉球）マークを出すか
    public let recommend: Bool
    public let mat: MatId
    public let blurb: String
    public let rules: [String]
    public let cpus: [CpuDef]
}

public enum Ranks {
    // kindOf(family, role)  family: 0三毛 1黒 2白 3茶トラ 4サバトラ 5ハチワレ / role: 0パパ 1ママ 2子猫
    public static let all: [RankDef] = [
        RankDef(
            id: "koneko", name: "子猫《こねこ》", level: 1, starsToNext: 3, furikomiPenalty: 0, recommend: true, mat: .ramune,
            blurb: "子猫《こねこ》たちと遊《あそ》ぼう。ときどき、うっかり捨《す》ててしまう相手《あいて》だよ。",
            rules: [],
            cpus: [CpuDef(name: "ミルク", avatar: kindOf(2, 2)), CpuDef(name: "チビ", avatar: kindOf(3, 2)), CpuDef(name: "ポン", avatar: kindOf(5, 2))]
        ),
        RankDef(
            id: "ieneko", name: "家猫《いえねこ》", level: 2, starsToNext: 4, furikomiPenalty: 0, recommend: true, mat: .ichigo,
            blurb: "揃《そろ》え方《かた》を考《かんが》えて捨《す》てる相手《あいて》。",
            rules: [],
            cpus: [CpuDef(name: "タマ", avatar: kindOf(0, 1)), CpuDef(name: "ソラ", avatar: kindOf(2, 0)), CpuDef(name: "モカ", avatar: kindOf(3, 1))]
        ),
        RankDef(
            id: "noraneko", name: "野良猫《のらねこ》", level: 3, starsToNext: 5, furikomiPenalty: 0, recommend: true, mat: .matcha,
            blurb: "残《のこ》りの猫《ねこ》を数《かぞ》えて、来《く》る可能性《かのうせい》が高《たか》い方《ほう》を選《えら》ぶ相手《あいて》。",
            rules: [],
            cpus: [CpuDef(name: "クロベエ", avatar: kindOf(1, 0)), CpuDef(name: "サバ", avatar: kindOf(4, 0)), CpuDef(name: "ハチ", avatar: kindOf(5, 1))]
        ),
        RankDef(
            id: "bossneko", name: "ボス猫《ねこ》", level: 4, starsToNext: 6, furikomiPenalty: 5, recommend: false, mat: .yozora,
            blurb: "相手《あいて》が捨《す》てた猫《ねこ》を読《よ》んで、危《あぶ》ない猫《ねこ》は捨《す》てない。",
            rules: ["おすすめマークなし", "上《あ》がられる猫《ねこ》を捨《す》てたら −5点《てん》"],
            cpus: [CpuDef(name: "ゴンザ", avatar: kindOf(1, 0)), CpuDef(name: "トラ吉《きち》", avatar: kindOf(3, 0)), CpuDef(name: "ギン", avatar: kindOf(4, 0))]
        ),
        RankDef(
            id: "nekogami", name: "猫神様《ねこがみさま》", level: 5, starsToNext: 6, furikomiPenalty: 5, recommend: false, mat: .hachimitsu,
            blurb: "一番《いちばん》強《つよ》い相手《あいて》。点数《てんすう》の高《たか》い上《あ》がりも狙《ねら》ってくる。",
            rules: ["おすすめマークなし", "上《あ》がられる猫《ねこ》を捨《す》てたら −5点《てん》", "★6つで王冠《おうかん》ゲット"],
            cpus: [CpuDef(name: "福丸《ふくまる》", avatar: joker), CpuDef(name: "コハク", avatar: kindOf(2, 1)), CpuDef(name: "ムサシ", avatar: kindOf(5, 0))]
        ),
    ]

    /// 1位で★2つ、2位で★1つ
    public static let starsForPlace = [2, 1, 0, 0]

    public static func unlockedMats(rank: Int) -> [MatId] {
        all.prefix(rank + 1).map(\.mat)
    }
}

/// ランクと★の進み具合
public struct RankProgress: Codable, Sendable, Equatable {
    public var rank = 0
    public var stars = 0
    public var crowns = 0
    public var tutorialDone = false
    public init() {}
}

public struct RankReward: Sendable, Equatable {
    public let gained: Int
    public let stars: Int
    public let need: Int
    public let rankedUp: Bool
    public let newRank: Int
    public let crowned: Bool
}

extension RankProgress {
    /// ★を足して、ランクアップや王冠を判定する
    public mutating func addStars(_ n: Int) -> RankReward {
        let need = Ranks.all[rank].starsToNext
        stars += n
        var rankedUp = false
        var crowned = false
        if stars >= need {
            if rank < Ranks.all.count - 1 {
                rank += 1
                rankedUp = true
            } else {
                crowns += 1
                crowned = true
            }
            stars = 0
        }
        return RankReward(gained: n, stars: stars, need: need, rankedUp: rankedUp, newRank: rank, crowned: crowned)
    }
}
