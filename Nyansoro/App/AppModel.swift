// アプリ全体の状態：今どの画面か、セーブデータ、広告。

import SwiftUI

enum GameMode: Hashable {
    case cpu(rank: Int)
    case tutorial
}

enum MatchReward: Equatable {
    case tutorial
    case practice(place: Int)
    case ranked(place: Int, reward: RankReward)
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

    /// 開発用ビルドではダミー広告、それ以外は広告なし（AdMob を入れたらここを差し替える）
    let debugAds = DebugAdService()
    var ads: AdService? {
        #if DEBUG
        return debugAds
        #else
        return nil
        #endif
    }

    #if DEBUG
    /// 開発用：場面指定（DebugScenarios.swift）で使う、対戦の最初の状態
    var debugInitialState: GameState?
    var debugOpenHelp = false
    #endif

    init() {
        save = SaveStore.load()
        applySettings()
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
    func matchEnded(mode: GameMode, place: Int) -> MatchReward {
        switch mode {
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
