// 開発用：起動時に `-scenario 名前` を渡すと、その場面から始まる（画面の自動撮影用）。
// 例）xcrun simctl launch <端末> com.example.nyansoro -scenario game
// リリース用のビルドには含まれない。

#if DEBUG
import Foundation

enum DebugScenario: String, CaseIterable {
    case title, ranks, tutorial, game, claim, help, settings
    case roundResult = "round-result"
    case matchResult = "match-result"
    case rankup
    case streak
    case revive
    case nearMiss = "near-miss"
    case dailyResult = "daily-result"

    static var current: DebugScenario? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-scenario"), i + 1 < args.count else { return nil }
        return DebugScenario(rawValue: args[i + 1])
    }
}

enum DemoStates {
    /// 起動を速くするため、場面ごとに当たりの種を決めてある（変えたら seeds を探し直す）
    /// 決まった種で CPU対戦を始め、自分はおすすめを捨てながら、stop が true になるまで進める
    static func play(mode: GameMode = .cpu(rank: 0), seeds: ClosedRange<UInt32> = 1...200, until stop: (GameState) -> Bool) -> GameState? {
        for seed in seeds {
            var s = GameController.makeState(mode: mode, seed: seed)
            var r = Mulberry32(seed: seed &+ 7)
            for _ in 0..<3000 {
                if stop(s) { return s }
                let a: Action
                switch s.phase {
                case .draw:
                    a = .draw
                case .discard:
                    let p = s.players[s.current]
                    if canWin(p.hand) {
                        a = .tsumo
                    } else if p.isHuman, let best = discardOptions(s, 0).min(by: { $0.dist < $1.dist }), let t = p.hand.last(where: { $0.kind == best.kind }) {
                        // 起動を速くするため、おすすめ（残り枚数の計算）は使わない
                        a = .discard(tileId: t.id)
                    } else {
                        a = .discard(tileId: chooseDiscard(s, s.current, level: 2, rand: { r.nextUnit() }))
                    }
                case .claim:
                    a = .ron(player: s.claimQueue[0])
                case .roundEnd:
                    a = .nextRound
                case .matchEnd:
                    a = .nextRound
                }
                if s.phase == .matchEnd { break }
                s.apply(a)
            }
        }
        return nil
    }
}

extension AppModel {
    func applyDebugScenario(_ scenario: DebugScenario) {
        save.settings.sound = false
        save.settings.haptics = false
        func startGame(_ state: GameState?, mode: GameMode = .cpu(rank: 0)) {
            debugInitialState = state
            screen = .game(mode, UUID())
        }
        switch scenario {
        case .title:
            break
        case .ranks:
            save.progress.rank = 2
            save.progress.stars = 1
            screen = .ranks
        case .tutorial:
            screen = .game(.tutorial, UUID())
        case .settings:
            showSettings = true
        case .game:
            startGame(DemoStates.play { $0.phase == .discard && $0.current == 0 && $0.players.reduce(0) { $0 + $1.discards.count } >= 12 })
        case .help:
            debugOpenHelp = true
            startGame(DemoStates.play { $0.phase == .discard && $0.current == 0 && $0.players.reduce(0) { $0 + $1.discards.count } >= 8 })
        case .claim:
            save.settings.autoNyan = false
            startGame(DemoStates.play(seeds: 3...3) { $0.phase == .claim && $0.claimQueue.first == 0 })
        case .roundResult:
            startGame(DemoStates.play(seeds: 3...3) { $0.phase == .roundEnd && $0.result?.winner == 0 })
        case .matchResult:
            save.ads.matchesFinished = 3
            startGame(DemoStates.play(seeds: 3...3) { $0.phase == .matchEnd && $0.place(of: 0) == 1 })
        case .streak:
            save.streak.current = 5
            save.streak.best = 5
            save.streak.lastDay = today - 1
            save.daily = nil
        case .revive:
            save.streak.current = 5
            save.streak.lastDay = today - 2
            save.daily = nil
        case .nearMiss:
            startGame(DemoStates.play(seeds: 1...1) { s in
                s.phase == .roundEnd && s.result?.winner != nil && s.result?.winner != 0
                    && s.players[0].hand.count == handSize && distance(countKinds(s.players[0].hand)) == 1
            })
        case .dailyResult:
            save.streak.current = 4
            save.streak.lastDay = today - 1
            save.daily = nil
            let mode = GameMode.daily(day: today)
            startGame(DemoStates.play(mode: mode, seeds: 1...1) { $0.phase == .matchEnd }, mode: mode)
        case .rankup:
            save.progress.rank = 0
            save.progress.stars = 2
            startGame(DemoStates.play(seeds: 10...10) { $0.phase == .matchEnd && $0.place(of: 0) == 0 })
        }
    }
}
#endif
