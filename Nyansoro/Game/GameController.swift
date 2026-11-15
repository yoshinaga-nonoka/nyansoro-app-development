// 対戦1回分の進行役。ルールは GameState.apply にまかせ、ここでは CPU の間合い・練習の台本・表示用の計算を扱う。

import SwiftUI

@MainActor
final class GameController: ObservableObject {
    let mode: GameMode
    unowned let app: AppModel

    @Published private(set) var state: GameState
    @Published var selectedId: Int?
    @Published private(set) var banner: String?
    @Published private(set) var tStep: Int
    @Published private(set) var nudge: String?
    @Published var reward: MatchReward?
    /// この試合の捨て方のふりかえり
    @Published private(set) var tally = DecisionTally()
    /// 今の局で達成した目標
    @Published private(set) var roundMissions: [MissionDef] = []
    /// 試合のふりかえり（試合が終わったら入る）
    @Published private(set) var review: MatchReview?
    @Published var showHelp = false { didSet { schedule() } }
    @Published var showSettings = false { didSet { schedule() } }
    @Published var showQuit = false { didSet { schedule() } }

    private var task: Task<Void, Never>?
    private var bannerTask: Task<Void, Never>?
    private var scriptDone = false
    private var cpuRandom: Mulberry32?
    private var ended = false

    init(mode: GameMode, app: AppModel) {
        self.mode = mode
        self.app = app
        self.tStep = mode == .tutorial ? 0 : -1
        if case let .daily(day) = mode { cpuRandom = Daily.cpuRandom(day: day) }
        #if DEBUG
        if let demo = app.debugInitialState {
            app.debugInitialState = nil
            self.state = demo
            if app.debugOpenHelp {
                app.debugOpenHelp = false
                showHelp = true
            }
            if demo.phase == .matchEnd {
                ended = true
                reward = app.matchEnded(mode: mode, state: demo)
                // 撮影用：ふりかえりの見本（実際の試合では捨てるたびに数える）
                var sample = DecisionTally()
                sample.best = 13
                sample.good = 2
                sample.miss = 1
                tally = sample
                review = app.recordMatch(demo, mode: mode, tally: sample)
            }
            return
        }
        #endif
        self.state = Self.newGame(mode)
        showBanner()
    }

    static func newGame(_ mode: GameMode) -> GameState {
        makeState(mode: mode, seed: UInt32.random(in: 0...UInt32.max))
    }

    nonisolated static func makeState(mode: GameMode, seed: UInt32) -> GameState {
        let human = PlayerSetup(name: "キミ", isHuman: true, level: 0, avatar: kindOf(0, 2))
        switch mode {
        case let .daily(day):
            return Daily.makeState(day: day, human: human)
        case .tutorial:
            let cpus = Ranks.all[0].cpus.map { PlayerSetup(name: $0.name, isHuman: false, level: 1, avatar: $0.avatar) }
            return GameState(setups: [human] + cpus, rules: Rules(rounds: 1, furikomiPenalty: 0), seed: 1, presetDeck: Tutorial.deck())
        case let .cpu(rank):
            let r = Ranks.all[rank]
            let cpus = r.cpus.map { PlayerSetup(name: $0.name, isHuman: false, level: r.level, avatar: $0.avatar) }
            return GameState(setups: [human] + cpus, rules: Rules(rounds: 4, furikomiPenalty: r.furikomiPenalty), seed: seed)
        }
    }

    // MARK: 表示用

    var tutorial: Bool { mode == .tutorial }
    var isDaily: Bool {
        if case .daily = mode { return true }
        return false
    }
    var titleText: String {
        if isDaily { return "今日《きょう》の1局《きょく》" }
        return tutorial ? "練習《れんしゅう》" : "\(rankDef?.name ?? "")ランク"
    }
    var rankDef: RankDef? {
        if case let .cpu(rank) = mode { return Ranks.all[rank] }
        return nil
    }
    var settings: Settings { app.settings }
    var hints: Bool { tutorial || settings.hints }
    var recommendOn: Bool { tutorial || (settings.hints && (rankDef?.recommend ?? true)) }
    var autoNyan: Bool { !tutorial && settings.autoNyan }
    var tutorialGate: Bool { tutorial && (tStep == 0 || tStep == 1 || tStep == 2) }
    var paused: Bool { showHelp || showSettings || showQuit || banner != nil || tutorialGate || app.debugAds.showing != nil }

    var me: PlayerState { state.players[0] }
    var myDiscardTurn: Bool { state.phase == .discard && state.current == 0 }
    var myDraw: Bool { state.phase == .draw && state.current == 0 }
    var myClaim: Bool { state.phase == .claim && state.claimQueue.first == 0 }
    var canTsumo: Bool { myDiscardTurn && canWin(me.hand) }
    var selectedTile: Tile? { selectedId.flatMap { id in me.hand.first { $0.id == id } } }

    struct Derived {
        var insight: Insight?
        var arrangement: Arrangement?
        var baseTiles: [Tile]
        var drawnTile: Tile?
        var recTileId: Int?
        /// あと1枚のとき、上がったら何点か（最小〜最大）
        var waitPoints: (min: Int, max: Int)?
    }

    private var derivedKey = ""
    private var derivedCache: Derived?

    /// 手の並べ替え・おすすめなど（手や捨て牌が変わったときだけ計算し直す）
    var derived: Derived {
        let key = "\(me.hand.map(\.id))|\(state.players.map(\.discards.count))|\(state.phase)|\(state.current)|\(hints)|\(recommendOn)"
        if key == derivedKey, let cached = derivedCache { return cached }
        let drawnId = myDiscardTurn ? state.drawn?.id : nil
        let base = me.hand.filter { $0.id != drawnId }
        let drawn = drawnId.flatMap { id in me.hand.first { $0.id == id } }
        let arrangement = hints ? arrange(base) : nil
        let insight = handInsight(state, seat: 0, recommendOn: recommendOn)
        var recTileId: Int?
        if myDiscardTurn, let rec = insight?.rec {
            if drawn?.kind == rec {
                recTileId = drawn?.id
            } else {
                let order = arrangement.map { $0.groups.flatMap(\.tiles) + $0.leftovers } ?? sortTiles(base)
                recTileId = order.last { $0.kind == rec }?.id
            }
        }
        var waitPoints: (min: Int, max: Int)?
        if hints, let ins = insight, ins.dist == 1 {
            if me.hand.count == handSize {
                waitPoints = Coaching.waitPoints(hand8: me.hand)
            } else if let rec = ins.rec, let i = me.hand.lastIndex(where: { $0.kind == rec }) {
                var hand8 = me.hand
                hand8.remove(at: i)
                waitPoints = Coaching.waitPoints(hand8: hand8)
            }
        }
        let d = Derived(insight: insight, arrangement: arrangement, baseTiles: base, drawnTile: drawn, recTileId: recTileId, waitPoints: waitPoints)
        derivedKey = key
        derivedCache = d
        return d
    }

    // MARK: 操作

    func act(_ action: Action) {
        guard let next = state.applying(action) else { return }
        let prev = state
        state = next
        let sound = SoundPlayer.shared
        switch action {
        case .discard: sound.discard()
        case .tsumo, .ron: sound.win()
        case .draw:
            if next.phase == .roundEnd { sound.sleep() } else if next.players[next.current].isHuman { sound.draw() }
        default: break
        }
        afterChange(from: prev)
    }

    private func afterChange(from prev: GameState) {
        if state.round != prev.round, state.phase == .draw { showBanner() }
        if !myDiscardTurn {
            selectedId = nil
            nudge = nil
        }
        if tutorial {
            if tStep == 10, state.phase == .discard, state.current == 0 { tStep = 2 }
            if tStep == 4, state.phase == .claim, state.claimQueue.first == 0 { tStep = 5 }
        }
        if state.phase == .roundEnd, prev.phase != .roundEnd {
            roundMissions = app.recordRound(state)
        } else if state.phase != .roundEnd {
            roundMissions = []
        }
        if state.phase == .matchEnd, !ended {
            ended = true
            reward = app.matchEnded(mode: mode, state: state)
            if !tutorial { review = app.recordMatch(state, mode: mode, tally: tally) }
            SoundPlayer.shared.fanfare()
        }
        schedule()
    }

    func tapTile(_ tile: Tile) {
        guard myDiscardTurn, !paused else { return }
        if selectedId == tile.id {
            discard(tile)
        } else {
            SoundPlayer.shared.tap()
            selectedId = tile.id
        }
    }

    func discard(_ tile: Tile) {
        if tutorial, tStep == 3, tile.kind != Tutorial.discardKind {
            nudge = "今回《こんかい》は肉球《にくきゅう》マークの猫《ねこ》を捨《す》ててね"
            return
        }
        selectedId = nil
        if tutorial, tStep == 3 { tStep = 4 }
        // 捨て方を評価して数える（練習・上がれる手のときは数えない）
        if !tutorial, myDiscardTurn, !canWin(me.hand), let grade = Coaching.grade(state, seat: 0, discarding: tile.kind) {
            switch grade {
            case .best: tally.best += 1
            case .good: tally.good += 1
            case .miss: tally.miss += 1
            }
        }
        act(.discard(tileId: tile.id))
    }

    func tutorialNext() {
        tStep = tStep == 0 ? 1 : tStep == 1 ? 10 : 3
        schedule()
    }

    func nextRound() {
        act(.nextRound)
    }

    func resume() {
        schedule()
    }

    private func showBanner() {
        if case .daily = mode {
            banner = "今日《きょう》の1局《きょく》"
        } else {
            banner = tutorial ? "練習《れんしゅう》" : "\(state.round + 1)局目《きょくめ》"
        }
        bannerTask?.cancel()
        bannerTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_300_000_000)
            guard let self, !Task.isCancelled else { return }
            self.banner = nil
            self.schedule()
        }
    }

    // MARK: CPU と自動操作の間合い

    func schedule() {
        task?.cancel()
        guard !paused else { return }
        let s = state
        let cur = s.players[s.current]
        let speed = settings.speed
        var delay: Double?
        var action: Action?
        var cpuTurn = false

        switch s.phase {
        case .draw:
            delay = cur.isHuman ? 0.26 : speed.draw
            action = .draw
        case .discard:
            if !cur.isHuman {
                delay = speed.think
                cpuTurn = true
            } else if autoNyan, canWin(cur.hand) {
                delay = 0.75
                action = .tsumo
            }
        case .claim:
            if let head = s.claimQueue.first {
                if !s.players[head].isHuman {
                    delay = 0.52
                    action = .ron(player: head)
                } else if autoNyan {
                    delay = 0.85
                    action = .ron(player: head)
                }
            }
        case .roundEnd, .matchEnd:
            break
        }

        guard let wait = delay else { return }
        task = Task { [weak self, action, cpuTurn] in
            try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            guard let self, !Task.isCancelled, !self.paused else { return }
            if cpuTurn {
                self.cpuMove()
            } else if let action {
                self.act(action)
            }
        }
    }

    private func cpuMove() {
        let s = state
        let p = s.players[s.current]
        if canWin(p.hand) {
            act(.tsumo)
            return
        }
        if tutorial, s.current == 1, !scriptDone, let t = p.hand.first(where: { $0.kind == Tutorial.winKind }) {
            scriptDone = true
            act(.discard(tileId: t.id))
            return
        }
        if var r = cpuRandom {
            // 今日の1局：CPU の迷い方も日付で決める
            let id = chooseDiscard(s, s.current, level: p.level, rand: { r.nextUnit() })
            cpuRandom = r
            act(.discard(tileId: id))
            return
        }
        act(.discard(tileId: chooseDiscard(s, s.current, level: p.level)))
    }

    // MARK: 広告

    func watchAdForStar() {
        Task {
            guard let r = await app.watchAdForStar(), case let .ranked(place, _)? = reward else { return }
            reward = .ranked(place: place, reward: r)
            SoundPlayer.shared.fanfare()
        }
    }
}
