// 今日の1局：日付から決まる、全員共通の配牌の1局勝負。
// 連続日数：今日の1局を遊んだ日が続いた数。1日だけ休んだときは、動画（リワード広告）で守れる。

import Foundation

public enum Daily {
    /// 2000年1月1日からの日数（端末のタイムゾーンで数える）
    public static func dayNumber(_ date: Date, calendar: Calendar = .current) -> Int {
        let epoch = calendar.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? Date(timeIntervalSince1970: 946_684_800)
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: epoch), to: calendar.startOfDay(for: date)).day ?? 0
    }

    /// その日の配牌の種（同じ日なら誰でも同じ）
    public static func seed(day: Int) -> UInt32 {
        var r = Mulberry32(seed: UInt32(truncatingIfNeeded: day) &* 2_654_435_761 ^ 0x5EED_CA75)
        return r.nextUInt32()
    }

    /// 相手は家猫ランクの3匹（毎日同じ強さで比べられるように）
    public static let rank = 1
    public static var cpus: [CpuDef] { Ranks.all[rank].cpus }

    public static func makeState(day: Int, human: PlayerSetup) -> GameState {
        let r = Ranks.all[rank]
        let cpuSetups = r.cpus.map { PlayerSetup(name: $0.name, isHuman: false, level: r.level, avatar: $0.avatar) }
        return GameState(setups: [human] + cpuSetups, rules: Rules(rounds: 1, furikomiPenalty: 0), seed: seed(day: day))
    }

    /// CPU の迷い方も日付で決める（同じ打ち方なら同じ展開になる）
    public static func cpuRandom(day: Int) -> Mulberry32 {
        Mulberry32(seed: seed(day: day) ^ 0x9E37_79B9)
    }
}

public struct DailyResult: Codable, Sendable, Equatable {
    public var day: Int
    public var won: Bool
    /// 何巡目で上がったか（上がれなかったら 0）
    public var turns: Int
    public var points: Int

    public init(day: Int, won: Bool, turns: Int, points: Int) {
        self.day = day
        self.won = won
        self.turns = turns
        self.points = points
    }
}

public struct StreakState: Codable, Sendable, Equatable {
    public var current = 0
    public var best = 0
    /// 最後に今日の1局を遊んだ日
    public var lastDay: Int?
    public var revivesUsed = 0

    public init() {}

    public enum Status: Equatable, Sendable {
        /// 今日はもう遊んだ
        case doneToday
        /// 昨日遊んだ。今日遊べば続く
        case keepGoing
        /// 1日休んだ。動画で守れば続く
        case revivable
        /// 途切れた
        case broken
        /// まだ始めていない
        case notStarted
    }

    public func status(today: Int) -> Status {
        guard let last = lastDay, current > 0 else { return .notStarted }
        switch today - last {
        case ..<1: return .doneToday
        case 1: return .keepGoing
        case 2: return .revivable
        default: return .broken
        }
    }

    /// 表示する連続日数（途切れていたら 0）
    public func displayCount(today: Int) -> Int {
        switch status(today: today) {
        case .doneToday, .keepGoing, .revivable: return current
        case .broken, .notStarted: return 0
        }
    }

    /// 1日休んだ分を埋める（動画を見たあとに呼ぶ）
    @discardableResult
    public mutating func revive(today: Int) -> Bool {
        guard status(today: today) == .revivable else { return false }
        lastDay = today - 1
        revivesUsed += 1
        return true
    }

    /// 今日の1局を遊び終えた
    public mutating func complete(today: Int) {
        switch status(today: today) {
        case .doneToday: return
        case .keepGoing: current += 1
        case .revivable, .broken, .notStarted: current = 1
        }
        lastDay = today
        best = max(best, current)
    }
}

/// 局が終わったときの一言（「漢字《よみ》」形式）。惜しかったときと、上がったときに出す
public enum Feedback {
    public static func roundMessage(_ s: GameState, seat: Int = 0) -> String? {
        guard let r = s.result else { return nil }
        let me = s.players[seat]
        if r.winner == seat, let win = r.win {
            if win.items.contains(ScoreTable.allSame) { return "全部《ぜんぶ》同《おな》じ猫《ねこ》！ お見事《みごと》！" }
            if win.items.contains(ScoreTable.allFamily) { return "家族《かぞく》が全員《ぜんいん》集合《しゅうごう》！ すごい！" }
            let streak = s.history.reversed().prefix { $0.winner == seat }.count
            if streak >= 2 { return "\(streak)回《かい》連続《れんぞく》で上《あ》がり！ 絶好調《ぜっこうちょう》！" }
            let turns = winTurns(s, seat: seat)
            if turns > 0, turns <= 3 { return "たった\(turns)巡目《じゅんめ》で上《あ》がり！ 速《はや》い！" }
            return "ナイス！ この調子《ちょうし》！"
        }
        if me.hand.count == handSize, distance(countKinds(me.hand)) == 1 {
            return "惜《お》しい！ あと1枚《まい》だった！"
        }
        if r.kind == .ron, r.from == seat {
            return "その猫《ねこ》は待《ま》たれていた… 次《つぎ》は相手《あいて》の捨《す》てた猫《ねこ》もよく見《み》よう"
        }
        return nil
    }

    /// 上がった人が何巡目で上がったか（自分が引いた回数）
    public static func winTurns(_ s: GameState, seat: Int) -> Int {
        guard let r = s.result, r.winner == seat else { return 0 }
        return s.players[seat].discards.count + (r.kind == .tsumo ? 1 : 0)
    }
}
