// アプリ全体の状態：今どの画面か、セーブデータ、広告。

import SwiftUI

enum GameMode: Hashable {
    case cpu(rank: Int)
    case tutorial
    /// 今日の1局（day は Daily.dayNumber）
    case daily(day: Int)
}

struct DailySummary: Equatable {
    let won: Bool
    let turns: Int
    let points: Int
    let streak: Int
    /// 勝ったときにもらえた★（今のランクに足す）
    let star: RankReward?
}

enum MatchReward: Equatable {
    case tutorial
    case practice(place: Int)
    case ranked(place: Int, reward: RankReward)
    case daily(DailySummary)
}

@MainActor
final class AppModel: ObservableObject {
    enum Screen: Equatable {
        case title
        case ranks
        case game(GameMode, UUID)
    }

    @Published var screen: Screen = .title
    @Published var save: SaveData {
        didSet {
            SaveStore.write(save)
            applySettings()
        }
    }
    @Published var showHelp = false
    @Published var showSettings = false
    @Published var showOnline = false

    /// 広告。AdMob が入っていれば AdMob（開発用はテスト広告）、なければ開発用ビルドだけダミー広告
    let debugAds = DebugAdService()
    #if canImport(GoogleMobileAds)
    private lazy var admob = AdMobAdService()
    var ads: AdService? {
        AdConfig.enabled ? admob : nil
    }
    #else
    var ads: AdService? {
        #if DEBUG
        return debugAds
        #else
        return nil
        #endif
    }
    #endif

    #if DEBUG
    /// 開発用：場面指定（DebugScenarios.swift）で使う、対戦の最初の状態
    var debugInitialState: GameState?
    var debugOpenHelp = false
    #endif

    init() {
        save = SaveStore.load()
        applySettings()
        refreshReminders()
        #if DEBUG
        if let scenario = DebugScenario.current { applyDebugScenario(scenario) }
        #endif
    }

    var settings: Settings { save.settings }
    var currentRank: RankDef { Ranks.all[save.progress.rank] }
    var unlockedMats: [MatId] { Ranks.unlockedMats(rank: save.progress.rank) }

    private func applySettings() {
        SoundPlayer.shared.soundOn = save.settings.sound
        SoundPlayer.shared.hapticsOn = save.settings.haptics
    }

    func play(_ mode: GameMode) {
        SoundPlayer.shared.tap()
        withAnimation(.easeOut(duration: 0.2)) { screen = .game(mode, UUID()) }
    }

    func showTitle() {
        withAnimation(.easeOut(duration: 0.2)) { screen = .title }
    }

    func showRanks() {
        withAnimation(.easeOut(duration: 0.2)) { screen = .ranks }
    }

    func resetData() {
        SaveStore.clear()
        save = SaveData()
    }

    /// 試合が終わったとき：★を足す（今のランクで遊んだときだけ）
    func matchEnded(mode: GameMode, state: GameState) -> MatchReward {
        let place = state.place(of: 0)
        switch mode {
        case let .daily(day):
            save.ads.recordMatchFinished()
            let won = state.history.last?.winner == 0
            let turns = won ? Feedback.winTurns(state, seat: 0) : 0
            save.streak.complete(today: day)
            save.daily = DailyResult(day: day, won: won, turns: turns, points: state.players[0].score)
            var star: RankReward?
            if won {
                var progress = save.progress
                let r = progress.addStars(1)
                save.progress = progress
                if r.rankedUp { save.settings.mat = Ranks.all[r.newRank].mat }
                star = r
            }
            refreshReminders()
            return .daily(DailySummary(won: won, turns: turns, points: state.players[0].score, streak: save.streak.current, star: star))
        case .tutorial:
            save.progress.tutorialDone = true
            return .tutorial
        case let .cpu(rank):
            save.ads.recordMatchFinished()
            guard rank == save.progress.rank else { return .practice(place: place) }
            var progress = save.progress
            let reward = progress.addStars(Ranks.starsForPlace[place])
            save.progress = progress
            if reward.rankedUp { save.settings.mat = Ranks.all[reward.newRank].mat }
            return .ranked(place: place, reward: reward)
        }
    }

    // MARK: 今日の1局・連続日数・お知らせ

    var today: Int { Daily.dayNumber(Date()) }
    var streakStatus: StreakState.Status { save.streak.status(today: today) }
    var streakCount: Int { save.streak.displayCount(today: today) }
    /// 今日の1局の結果（今日まだなら nil）
    var todaysDaily: DailyResult? { save.daily?.day == today ? save.daily : nil }
    var canReviveStreak: Bool { ads != nil && streakStatus == .revivable }

    /// 1日休んだ連続記録を、動画を見て守る
    func reviveStreak() async {
        guard let ads, streakStatus == .revivable else { return }
        guard await ads.showRewarded() else { return }
        save.streak.revive(today: today)
        SoundPlayer.shared.fanfare()
    }

    func refreshReminders() {
        DailyReminder.reschedule(enabled: save.settings.reminders, doneToday: streakStatus == .doneToday, streak: streakCount)
    }

    /// 通知の許可を聞いて、許可されたら予約する
    func enableReminders() {
        save.askedReminders = true
        DailyReminder.requestPermission { [weak self] granted in
            guard let self else { return }
            self.save.settings.reminders = granted
            self.refreshReminders()
        }
    }

    /// リワード広告を出してよいか
    var canOfferReward: Bool {
        ads != nil && save.ads.canOfferReward()
    }

    /// 動画を見たら★を1個足す。見なかったら nil
    func watchAdForStar() async -> RankReward? {
        guard let ads, save.ads.canOfferReward() else { return nil }
        guard await ads.showRewarded() else { return nil }
        save.ads.recordReward()
        var progress = save.progress
        let reward = progress.addStars(1)
        save.progress = progress
        if reward.rankedUp { save.settings.mat = Ranks.all[reward.newRank].mat }
        return reward
    }

    /// 試合の結果画面から移るとき：決まりに合えば全画面広告を出してから移る
    func leaveMatch(then next: @escaping () -> Void) {
        guard let ads, save.ads.canShowInterstitial() else {
            next()
            return
        }
        save.ads.recordInterstitial()
        Task {
            await ads.showInterstitial()
            next()
        }
    }
}
