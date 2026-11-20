// アプリ全体の状態：今どの画面か、セーブデータ、広告。

import SwiftUI

enum GameMode: Hashable {
    case cpu(rank: Int)
    /// 練習（チュートリアルタスク）
    case tutorial(TutorialTask)
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
    case tutorial(task: TutorialTask, cleared: Bool)
    case practice(place: Int)
    case ranked(place: Int, reward: RankReward)
    case daily(DailySummary)
}

@MainActor
final class AppModel: ObservableObject {
    enum Screen: Equatable {
        /// 初めて起動したときの説明（ホームの前）
        case onboarding
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
    @Published var showLesson = false
    @Published var showMissions = false
    /// 練習の一覧
    @Published var showPractice = false
    /// 初回の説明を「遊び方」から見直す
    @Published var showIntro = false
    /// Apple でサインインしたアカウント（キーチェーンに保存）
    @Published private(set) var account: AppleAccount? = nil

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
    /// 練習の案内をこの段階から始める
    var debugTutorialStep: Int?
    /// おすすめの猫を選んだ状態で始める
    var debugSelectRecommended = false
    #endif

    init() {
        save = SaveStore.load()
        account = AccountConfig.enabled ? AccountStore.load() : nil
        applySettings()
        refreshReminders()
        if !save.onboarding.introDone { screen = .onboarding }
        #if DEBUG
        if let scenario = DebugScenario.current { applyDebugScenario(scenario) }
        #endif
        checkAccount()
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
        var fresh = SaveData()
        // 消したあとに、もう一度ホームの前の説明を見せることはしない
        fresh.onboarding.introDone = true
        fresh.onboarding.signInOffered = save.onboarding.signInOffered
        save = fresh
        pushToCloud()
    }

    /// 初回の説明を終える。練習を選んだらそのまま始める
    func finishIntro(start task: TutorialTask?) {
        save.onboarding.introDone = true
        save.onboarding.signInOffered = true
        showIntro = false
        if let task {
            play(.tutorial(task))
        } else if screen == .onboarding {
            showTitle()
        }
    }

    /// 初回の説明を「遊び方」から見直す（シートを閉じてから出す）
    func replayIntro() {
        showHelp = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.showIntro = true
        }
    }

    // MARK: Apple でサインイン・iCloud

    func signedIn(_ new: AppleAccount) {
        var acc = new
        // 名前とメールは初回しか届かないので、前に保存したものを残す
        if let old = AccountStore.load(), old.userID == new.userID {
            acc.name = new.name ?? old.name
            acc.email = new.email ?? old.email
            acc.firstSignIn = old.firstSignIn
            acc.signInCount = old.signInCount + 1
        }
        AccountStore.save(acc)
        account = acc
        save.onboarding.signInOffered = true
        syncWithCloud()
    }

    func signOut() {
        AccountStore.clear()
        account = nil
    }

    /// 起動時：サインインがまだ有効か確かめる（設定でアプリとの連携を外した場合など）
    private func checkAccount() {
        guard AccountConfig.enabled, let id = account?.userID else { return }
        AppleSignIn.checkStillValid(userID: id) { [weak self] valid in
            if valid { self?.syncWithCloud() } else { self?.signOut() }
        }
    }

    /// iCloud の記録と合わせる：遊んだ局数が多い方を残す（設定はこの端末のまま）
    func syncWithCloud() {
        guard CloudSave.enabled, let user = account?.userID else { return }
        Task {
            do {
                if let remote = try await CloudSave.load(user: user), remote.stats.rounds > save.stats.rounds {
                    var merged = remote
                    merged.settings = save.settings
                    merged.onboarding.introDone = true
                    save = merged
                } else {
                    try await CloudSave.store(save, user: user)
                }
            } catch {
                // iCloud に入っていない・電波がないときは、端末の記録だけで続ける
            }
        }
    }

    /// 試合が終わったときなど：iCloud に今の記録を置く
    func pushToCloud() {
        guard CloudSave.enabled, let user = account?.userID else { return }
        let snapshot = save
        Task { try? await CloudSave.store(snapshot, user: user) }
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
            pushToCloud()
            return .daily(DailySummary(won: won, turns: turns, points: state.players[0].score, streak: save.streak.current, star: star))
        case let .tutorial(task):
            let cleared = task.isCleared(state.history.last)
            if cleared {
                if !save.cleared(task) { save.tutorialTasks.append(task.rawValue) }
                if task == .basics { save.progress.tutorialDone = true }
                pushToCloud()
            }
            return .tutorial(task: task, cleared: cleared)
        case let .cpu(rank):
            save.ads.recordMatchFinished()
            guard rank == save.progress.rank else { return .practice(place: place) }
            var progress = save.progress
            let reward = progress.addStars(Ranks.starsForPlace[place])
            save.progress = progress
            if reward.rankedUp { save.settings.mat = Ranks.all[reward.newRank].mat }
            pushToCloud()
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
