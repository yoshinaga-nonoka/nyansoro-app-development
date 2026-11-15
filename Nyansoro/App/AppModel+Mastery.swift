// 上達のしくみ：目標・成績・試合のふりかえり

import Foundation

/// 試合のあとのふりかえり
struct MatchReview: Equatable {
    let tally: DecisionTally
    let tip: String
    let missions: [MissionID]
}

extension AppModel {
    /// 局が終わったとき：成績を付けて、達成した目標を返す
    func recordRound(_ state: GameState) -> [MissionDef] {
        var progress = save.missions
        var stats = save.stats
        let done = MissionTracker.roundEnded(state, progress: &progress, stats: &stats)
        save.missions = progress
        save.stats = stats
        return done
    }

    /// 試合が終わったとき：ふりかえりと、試合単位の目標
    func recordMatch(_ state: GameState, mode: GameMode, tally: DecisionTally) -> MatchReview {
        var rank: Int?
        if case let .cpu(r) = mode { rank = r }
        var progress = save.missions
        var stats = save.stats
        var done = MissionTracker.matchEnded(state, rank: rank, tally: tally, progress: &progress, stats: &stats)
        if case .daily = mode {
            done += MissionTracker.streakUpdated(save.streak.current, progress: &progress)
        }
        save.missions = progress
        save.stats = stats
        return MatchReview(tally: tally, tip: Coaching.tip(tally: tally, state: state, rank: rank), missions: done.map(\.id))
    }

    /// 今のランクの次（最上位なら nil）
    var nextRank: RankDef? {
        let next = save.progress.rank + 1
        return next < Ranks.all.count ? Ranks.all[next] : nil
    }
}
