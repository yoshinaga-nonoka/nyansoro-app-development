// 上達のしくみ：目標（達成すると称号）、成績、捨て方のふりかえり。
// 「強くなりたい」と思えるように、目標そのものが点数や上がり方のルールを教える作りにしている。

public enum MissionID: String, CaseIterable, Codable, Sendable {
    case firstWin, tsumoWin, noJokerWin, fastWin, matchFirst, streak3
    case allFamilyWin, allSameWin, bigWin, wins10, sharpPlay, beatNora, streak7
    case perfectWin, wins50, beatBoss, beatGod
}

public struct MissionDef: Sendable, Identifiable {
    public let id: MissionID
    /// 目標の名前
    public let title: String
    /// どうすれば達成できるか（ルールの説明を兼ねる）
    public let detail: String
    /// 達成でもらえる称号
    public let badge: String
    public let target: Int
    /// 1:かんたん 2:ふつう 3:むずかしい
    public let tier: Int
}

public enum Missions {
    public static let all: [MissionDef] = [
        MissionDef(id: .firstWin, title: "初《はじ》めての上《あ》がり", detail: "9枚《まい》で3組《くみ》揃《そろ》えたら、にゃん！ 上《あ》がるだけで10点《てん》。", badge: "はじめの一歩《いっぽ》", target: 1, tier: 1),
        MissionDef(id: .tsumoWin, title: "自分《じぶん》で引《ひ》いて上《あ》がる", detail: "山《やま》から引《ひ》いた猫《ねこ》で揃《そろ》うと +5点《てん》。", badge: "引《ひ》きの強《つよ》い猫《ねこ》", target: 1, tier: 1),
        MissionDef(id: .noJokerWin, title: "招《まね》き猫《ねこ》なしで上《あ》がる", detail: "招《まね》き猫《ねこ》を使《つか》わずに揃《そろ》えると +5点《てん》。便利《べんり》だけど、使《つか》わない方《ほう》が点《てん》は高《たか》い。", badge: "招《まね》き猫《ねこ》いらず", target: 1, tier: 1),
        MissionDef(id: .fastWin, title: "3巡目《じゅんめ》までに上《あ》がる", detail: "配牌《はいぱい》がいいときはチャンス。バラバラの猫《ねこ》から迷《まよ》わず捨《す》てよう。", badge: "早上《はやあ》がり", target: 1, tier: 1),
        MissionDef(id: .matchFirst, title: "試合《しあい》で1位《い》になる", detail: "4局《きょく》の合計《ごうけい》でいちばん。1位《い》は★2つ。", badge: "初優勝《はつゆうしょう》", target: 1, tier: 1),
        MissionDef(id: .streak3, title: "今日《きょう》の1局《きょく》を3日《か》連続《れんぞく》", detail: "毎日《まいにち》1局《きょく》だけでOK。勝《か》てば★1つ。", badge: "三日坊主《みっかぼうず》じゃない", target: 3, tier: 1),
        MissionDef(id: .allFamilyWin, title: "全部《ぜんぶ》家族《かぞく》で上《あ》がる", detail: "3組《くみ》ともパパ・ママ・子猫《こねこ》で揃《そろ》えると +10点《てん》。家族《かぞく》が2組《くみ》できたら、3組目《くみめ》も家族《かぞく》を狙《ねら》おう。", badge: "家族思《かぞくおも》い", target: 1, tier: 2),
        MissionDef(id: .allSameWin, title: "全部《ぜんぶ》同《おな》じ猫《ねこ》で上《あ》がる", detail: "3組《くみ》とも同《おな》じ猫《ねこ》3枚《まい》で揃《そろ》えると +10点《てん》。2枚《まい》ある猫《ねこ》を大事《だいじ》にしよう。", badge: "そっくりさん", target: 1, tier: 2),
        MissionDef(id: .bigWin, title: "25点《てん》以上《いじょう》で上《あ》がる", detail: "ボーナスを2つ以上《いじょう》重《かさ》ねると25点《てん》。例《れい》：全部《ぜんぶ》家族《かぞく》＋招《まね》き猫《ねこ》なし。", badge: "高得点《こうとくてん》ハンター", target: 1, tier: 2),
        MissionDef(id: .wins10, title: "通算《つうさん》10回《かい》上《あ》がる", detail: "上《あ》がった回数《かいすう》。練習《れんしゅう》も今日《きょう》の1局《きょく》も数《かぞ》える。", badge: "上《あ》がり上手《じょうず》", target: 10, tier: 2),
        MissionDef(id: .sharpPlay, title: "名人《めいじん》の捨《す》て方《かた》", detail: "1試合《しあい》で「ベストな捨《す》て方《かた》」を90%以上《いじょう》（15回《かい》以上《いじょう》捨《す》てた試合《しあい》）。", badge: "名人《めいじん》の目《め》", target: 1, tier: 2),
        MissionDef(id: .beatNora, title: "野良猫《のらねこ》ランクで1位《い》", detail: "残《のこ》りの猫《ねこ》を数《かぞ》える相手《あいて》に勝《か》つ。", badge: "野良猫《のらねこ》の親分《おやぶん》", target: 1, tier: 2),
        MissionDef(id: .streak7, title: "今日《きょう》の1局《きょく》を7日《か》連続《れんぞく》", detail: "1週間《しゅうかん》毎日《まいにち》。1日《にち》休《やす》んでも動画《どうが》で守《まも》れる。", badge: "毎日《まいにち》の猫《ねこ》", target: 7, tier: 2),
        MissionDef(id: .perfectWin, title: "30点《てん》満点《まんてん》で上《あ》がる", detail: "全部《ぜんぶ》同《おな》じ猫《ねこ》（か全部《ぜんぶ》家族《かぞく》）＋招《まね》き猫《ねこ》なし＋自分《じぶん》で引《ひ》いて上《あ》がり＝30点《てん》。", badge: "満点《まんてん》の猫《ねこ》", target: 1, tier: 3),
        MissionDef(id: .wins50, title: "通算《つうさん》50回《かい》上《あ》がる", detail: "コツコツ上《あ》がり続《つづ》けよう。", badge: "上《あ》がりの達人《たつじん》", target: 50, tier: 3),
        MissionDef(id: .beatBoss, title: "ボス猫《ねこ》ランクで1位《い》", detail: "危《あぶ》ない猫《ねこ》を捨《す》てない相手《あいて》。上《あ》がられると −5点《てん》なので、相手《あいて》の捨《す》てた猫《ねこ》もよく見《み》よう。", badge: "ボス猫《ねこ》に勝《か》った", target: 1, tier: 3),
        MissionDef(id: .beatGod, title: "猫神様《ねこがみさま》に勝《か》つ", detail: "いちばん強《つよ》い相手《あいて》で1位《い》。", badge: "猫神様《ねこがみさま》に勝《か》った", target: 1, tier: 3),
    ]

    public static func def(_ id: MissionID) -> MissionDef {
        all.first { $0.id == id }!
    }
}

/// 目標の進み具合
public struct MissionProgress: Codable, Sendable, Equatable {
    public var counts: [String: Int] = [:]
    /// 達成した目標（達成した順）
    public var done: [String] = []

    public init() {}

    public func count(_ id: MissionID) -> Int { counts[id.rawValue] ?? 0 }
    public func isDone(_ id: MissionID) -> Bool { done.contains(id.rawValue) }
    public var latestBadge: String? { done.last.flatMap { MissionID(rawValue: $0) }.map { Missions.def($0).badge } }

    /// 進み具合を足す。今回で達成したらその目標を返す
    public mutating func add(_ id: MissionID, _ n: Int = 1) -> MissionDef? {
        guard !isDone(id) else { return nil }
        counts[id.rawValue, default: 0] += n
        return checkDone(id)
    }

    /// 進み具合を「今の値」にする（連続日数など、増えたり戻ったりするもの）
    public mutating func setAtLeast(_ id: MissionID, _ value: Int) -> MissionDef? {
        guard !isDone(id) else { return nil }
        counts[id.rawValue] = max(count(id), value)
        return checkDone(id)
    }

    private mutating func checkDone(_ id: MissionID) -> MissionDef? {
        let d = Missions.def(id)
        guard count(id) >= d.target else { return nil }
        done.append(id.rawValue)
        return d
    }
}

/// 通算の成績
public struct PlayStats: Codable, Sendable, Equatable {
    public var matches = 0
    public var rounds = 0
    public var wins = 0
    public var bestPoints = 0
    /// 最速の上がり（巡目、0 はまだなし）
    public var fastestWin = 0
    public var decisions = 0
    public var bestDecisions = 0

    public init() {}

    public var winRate: Double { rounds == 0 ? 0 : Double(wins) / Double(rounds) }
    public var accuracy: Double { decisions == 0 ? 0 : Double(bestDecisions) / Double(decisions) }
}

/// 1試合の捨て方のふりかえり
public struct DecisionTally: Codable, Sendable, Equatable {
    /// いちばん良い捨て方（あと何枚が増えず、来る猫の数も最大）
    public var best = 0
    /// 悪くない捨て方（あと何枚は増えない）
    public var good = 0
    /// 遠回り（あと何枚が増えた）
    public var miss = 0

    public init() {}

    public var total: Int { best + good + miss }
    public var accuracy: Double { total == 0 ? 0 : Double(best) / Double(total) }
}

public enum DiscardGrade: Equatable, Sendable {
    case best, good, miss
}

public enum Coaching {
    /// 9枚の手から kind を捨てる判断を評価する（捨てる前の状態で呼ぶ）
    public static func grade(_ s: GameState, seat: Int, discarding kind: Int) -> DiscardGrade? {
        let opts = discardOptions(s, seat, ukeire: true)
        guard let chosen = opts.first(where: { $0.kind == kind }), let bestDist = opts.map(\.dist).min() else { return nil }
        if chosen.dist > bestDist { return .miss }
        let bestUkeire = opts.filter { $0.dist == bestDist }.map(\.ukeire).max() ?? 0
        return chosen.ukeire >= bestUkeire ? .best : .good
    }

    /// 試合のあとの一言（「漢字《よみ》」形式）
    public static func tip(tally: DecisionTally, state: GameState, seat: Int = 0, rank: Int?) -> String {
        let myWins = state.history.filter { $0.winner == seat }.count
        let dealtIn = state.history.filter { $0.kind == .ron && $0.from == seat }.count
        let sleeps = state.history.filter { $0.kind == .exhausted }.count
        if tally.miss >= 2 {
            return "遠回《とおまわ》りの捨《す》て方《かた》が\(tally.miss)回《かい》。揃《そろ》いかけの組《くみ》を崩《くず》さず、バラバラの猫《ねこ》から捨《す》てよう。"
        }
        if dealtIn >= 1, (rank ?? 0) >= 3 {
            return "上《あ》がられた猫《ねこ》に注意《ちゅうい》。相手《あいて》があまり捨《す》てない家族《かぞく》の猫《ねこ》は、集《あつ》められているかも。"
        }
        if myWins == 0, sleeps >= 1 {
            return "揃《そろ》うのが少《すこ》し遅《おそ》め。2枚《まい》ある組《くみ》と、家族《かぞく》が2匹《ひき》いる組《くみ》を大事《だいじ》にしよう。"
        }
        if tally.total > 0, tally.accuracy >= 0.9 {
            return "判断《はんだん》はばっちり！ 次《つぎ》は点《てん》の高《たか》い上《あ》がりを狙《ねら》おう（全部《ぜんぶ》家族《かぞく》＋招《まね》き猫《ねこ》なしで +15点《てん》）。"
        }
        return "上《あ》がれる形《かたち》が見《み》えたら、点《てん》の高《たか》い揃《そろ》え方《かた》も考《かんが》えてみよう。"
    }

    /// 8枚の手で「あと1枚」のとき、上がったら何点になるか（最小・最大）
    public static func waitPoints(hand8: [Tile]) -> (min: Int, max: Int)? {
        let counts = countKinds(hand8)
        let waits = waitingKinds(counts)
        guard !waits.isEmpty else { return nil }
        var lo = Int.max, hi = 0
        for k in waits {
            let hand = hand8 + [Tile(id: -1, kind: k)]
            if let ron = scoreWin(hand, tsumo: false) { lo = min(lo, ron.total) }
            if let tsumo = scoreWin(hand, tsumo: true) { hi = max(hi, tsumo.total) }
        }
        return lo == Int.max ? nil : (lo, hi)
    }
}

public enum MissionTracker {
    /// 局が終わったとき：成績と目標を進める。今回達成した目標を返す
    public static func roundEnded(_ s: GameState, seat: Int = 0, progress: inout MissionProgress, stats: inout PlayStats) -> [MissionDef] {
        guard let r = s.result else { return [] }
        stats.rounds += 1
        guard r.winner == seat, let win = r.win else { return [] }
        let turns = Feedback.winTurns(s, seat: seat)
        stats.wins += 1
        stats.bestPoints = max(stats.bestPoints, win.total)
        if turns > 0, stats.fastestWin == 0 || turns < stats.fastestWin { stats.fastestWin = turns }
        var done: [MissionDef] = []
        func add(_ id: MissionID, _ ok: Bool = true) {
            if ok, let d = progress.add(id) { done.append(d) }
        }
        add(.firstWin)
        add(.wins10)
        add(.wins50)
        add(.tsumoWin, r.kind == .tsumo)
        add(.noJokerWin, win.items.contains(ScoreTable.noJoker))
        add(.allFamilyWin, win.items.contains(ScoreTable.allFamily))
        add(.allSameWin, win.items.contains(ScoreTable.allSame))
        add(.fastWin, turns > 0 && turns <= 3)
        add(.bigWin, win.total >= 25)
        add(.perfectWin, win.total >= 30)
        return done
    }

    /// 試合が終わったとき（rank は CPU 対戦のランク。練習・今日の1局は nil）
    public static func matchEnded(_ s: GameState, seat: Int = 0, rank: Int?, tally: DecisionTally, progress: inout MissionProgress, stats: inout PlayStats) -> [MissionDef] {
        stats.matches += 1
        stats.decisions += tally.total
        stats.bestDecisions += tally.best
        var done: [MissionDef] = []
        func add(_ id: MissionID, _ ok: Bool) {
            if ok, let d = progress.add(id) { done.append(d) }
        }
        let first = s.place(of: seat) == 0
        if let rank {
            add(.matchFirst, first)
            add(.beatNora, first && rank == 2)
            add(.beatBoss, first && rank == 3)
            add(.beatGod, first && rank == 4)
        }
        add(.sharpPlay, tally.total >= 15 && tally.accuracy >= 0.9)
        return done
    }

    /// 今日の1局を遊んだあと：連続日数の目標
    public static func streakUpdated(_ count: Int, progress: inout MissionProgress) -> [MissionDef] {
        [progress.setAtLeast(.streak3, count), progress.setAtLeast(.streak7, count)].compactMap { $0 }
    }
}
