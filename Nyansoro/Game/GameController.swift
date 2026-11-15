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
        if case .tutorial = mode { self.tStep = 0 } else { self.tStep = -1 }
        if case let .daily(day) = mode { cpuRandom = Daily.cpuRandom(day: day) }
        #if DEBUG
        if let demo = app.debugInitialState {
            app.debugInitialState = nil
            self.state = demo
            if app.debugOpenHelp {
                app.debugOpenHelp = false
                showHelp = true
            }
            if let step = app.debugTutorialStep {
                app.debugTutorialStep = nil
                tStep = step
            }
            if app.debugSelectRecommended {
                app.debugSelectRecommended = false
                if let rec = handInsight(demo, seat: 0, recommendOn: true)?.rec {
                    selectedId = demo.players[0].hand.last { $0.kind == rec }?.id
                }
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
        case let .tutorial(task):
            let cpus = Ranks.all[0].cpus.map { PlayerSetup(name: $0.name, isHuman: false, level: 1, avatar: $0.avatar) }
            return GameState(setups: [human] + cpus, rules: Rules(rounds: 1, furikomiPenalty: 0), seed: 1, presetDeck: task.deck())
        case let .cpu(rank):
            let r = Ranks.all[rank]
            let cpus = r.cpus.map { PlayerSetup(name: $0.name, isHuman: false, level: r.level, avatar: $0.avatar) }
            return GameState(setups: [human] + cpus, rules: Rules(rounds: 4, furikomiPenalty: r.furikomiPenalty), seed: seed)
        }
    }

    // MARK: 表示用

    /// 練習中なら、その練習
    var task: TutorialTask? {
        if case let .tutorial(t) = mode { return t }
        return nil
    }
    var tutorial: Bool { task != nil }
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
    var tutorialGate: Bool {
        guard let task else { return false }
        return task == .basics ? (tStep == 0 || tStep == 1 || tStep == 2) : tStep == 0
    }
    var paused: Bool { showHelp || showSettings || showQuit || banner != nil || tutorialGate || app.debugAds.showing != nil }

    var me: PlayerState { state.players[0] }
    var myDiscardTurn: Bool { state.phase == .discard && state.current == 0 }
    var myDraw: Bool { state.phase == .draw && state.current == 0 }
    var myClaim: Bool { state.phase == .claim && state.claimQueue.first == 0 }
    var canTsumo: Bool { myDiscardTurn && canWin(me.hand) }
    /// 選んでいる猫を捨てるとリーチできる
    var canRiichiSelected: Bool {
        guard myDiscardTurn, let id = selectedId, !canWin(me.hand) else { return false }
        return state.canRiichi(seat: 0, discarding: id)
    }
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
        let key = "\(me.hand.map(\.id))|\(me.riichi)|\(state.players.map(\.discards.count))|\(state.phase)|\(state.current)|\(hints)|\(recommendOn)"
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
                waitPoints = Coaching.waitPoints(hand8: me.hand, riichi: me.riichi)
            } else if let rec = ins.rec, let i = me.hand.lastIndex(where: { $0.kind == rec }) {
                var hand8 = me.hand
                hand8.remove(at: i)
                waitPoints = Coaching.waitPoints(hand8: hand8, riichi: me.riichi)
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
        case .discard, .riichi: sound.discard()
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
        if task == .basics {
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
        if me.riichi, tile.id != state.drawn?.id {
            nudge = "リーチ中《ちゅう》は、引《ひ》いた猫《ねこ》しか捨《す》てられないよ"
            return
        }
        if selectedId == tile.id {
            discard(tile)
        } else {
            SoundPlayer.shared.tap()
            selectedId = tile.id
        }
    }

    func discard(_ tile: Tile) {
        guard scriptAllows(tile, riichi: false) else { return }
        selectedId = nil
        if task == .basics, tStep == 3 { tStep = 4 }
        grade(tile)
        act(.discard(tileId: tile.id))
    }

    /// リーチして捨てる
    func declareRiichi(_ tile: Tile) {
        guard myDiscardTurn, state.canRiichi(seat: 0, discarding: tile.id), scriptAllows(tile, riichi: true) else { return }
        selectedId = nil
        grade(tile)
        SoundPlayer.shared.fanfare()
        act(.riichi(tileId: tile.id))
    }

    /// 練習の台本どおりか（違うときは一言出して止める）
    private func scriptAllows(_ tile: Tile, riichi: Bool) -> Bool {
        guard let task, myDiscardTurn, !me.riichi else { return true }
        let rec: Int? = task == .basics ? Tutorial.discardKind : handInsight(state, seat: 0, recommendOn: true)?.rec
        if task == .basics, tStep != 3 { return true }
        if let rec, tile.kind != rec {
            nudge = "今回《こんかい》は肉球《にくきゅう》マークの猫《ねこ》を捨《す》ててね"
            return false
        }
        if task == .riichi, !riichi, state.canRiichi(seat: 0, discarding: tile.id) {
            nudge = "今回《こんかい》は**リーチ**ボタンで捨《す》ててね"
            return false
        }
        return true
    }

    /// 捨て方を評価して数える（練習・上がれる手・リーチ中は数えない）
    private func grade(_ tile: Tile) {
        guard !tutorial, myDiscardTurn, !me.riichi, !canWin(me.hand), let grade = Coaching.grade(state, seat: 0, discarding: tile.kind) else { return }
        switch grade {
        case .best: tally.best += 1
        case .good: tally.good += 1
        case .miss: tally.miss += 1
        }
    }

    func tutorialNext() {
        if task == .basics {
            tStep = tStep == 0 ? 1 : tStep == 1 ? 10 : 3
        } else {
            tStep = 20
        }
        schedule()
    }

    /// 練習の案内の一言（「漢字《よみ》」形式）
    var tutorialLine: String {
        guard let task else { return "" }
        if task == .basics { return basicsLine(tStep) }
        let ins = derived.insight
        let goal: String
        let readyLine: String
        let waitingLine: String
        switch task {
        case .riichi:
            goal = "**目標《もくひょう》：リーチして上《あ》がろう**。あと1枚《まい》で揃《そろ》う形《かたち》になったら「リーチ」と言《い》える。上《あ》がると +10点《てん》！"
            readyLine = "**あと1枚《まい》**の形《かたち》になる！ 肉球《にくきゅう》の猫《ねこ》を選《えら》んで、**リーチ**ボタンを押《お》そう"
            waitingLine = "リーチ中《ちゅう》！ 手《て》は変《か》えられないけど、上《あ》がれば +10点《てん》。次《つぎ》に捨《す》てる前《まえ》に上《あ》がると**すぐにゃん** +5点《てん》"
        default:
            goal = "**目標《もくひょう》：役《やく》を作《つく》って点数《てんすう》を上《あ》げよう**。家族《かぞく》セットを3つ揃《そろ》えると「全部《ぜんぶ》家族《かぞく》」で +10点《てん》！"
            readyLine = me.discards.isEmpty
                ? "家族《かぞく》セットが2つ！ サバトラの**子猫《こねこ》**を捨《す》てて、3つ目《め》も家族《かぞく》を狙《ねら》おう（リーチしてもOK）"
                : "肉球《にくきゅう》の猫《ねこ》を捨《す》てよう。リーチすると +10点《てん》上乗《うわの》せ"
            waitingLine = "サバトラの**ママ**が来《く》れば全部《ぜんぶ》家族《かぞく》！ 待《ま》ってみよう"
        }
        if tStep == 0 { return goal }
        if myClaim || canTsumo {
            return task == .riichi ? "揃《そろ》った！ **にゃん！**を押《お》そう。リーチの点数《てんすう》も付《つ》くよ" : "揃《そろ》った！ **にゃん！**で「全部《ぜんぶ》家族《かぞく》」の上《あ》がり"
        }
        if myDiscardTurn, me.riichi { return "リーチ中《ちゅう》は、引《ひ》いた猫《ねこ》をそのまま捨《す》てるよ" }
        if myDiscardTurn, ins?.canRiichi == true { return readyLine }
        if myDiscardTurn { return "肉球《にくきゅう》マークの猫《ねこ》を2回《かい》タップして捨《す》てよう" }
        if me.riichi || ins?.dist == 1 { return waitingLine }
        return "他《ほか》の人《ひと》の番《ばん》。待《ま》ってみよう"
    }

    private func basicsLine(_ step: Int) -> String {
        switch step {
        case 0: return "これがキミの手《て》。猫《ねこ》が8枚《まい》あるよ。**3枚《まい》セットを3つ**作《つく》ったら勝《か》ち！"
        case 1: return "**三毛《みけ》のパパが3枚《まい》**！ 同《おな》じ猫《ねこ》3枚《まい》でセット完成《かんせい》。緑《みどり》の線《せん》が目印《めじるし》だよ。"
        case 10: return "山《やま》から1枚《まい》引《ひ》くよ…"
        case 2: return "**黒《くろ》の子猫《こねこ》**を引《ひ》いた！ 黒《くろ》のパパ・ママ・子猫《こねこ》で**家族《かぞく》セット**完成《かんせい》。"
        case 3: return "いらない猫《ねこ》を捨《す》てよう。肉球《にくきゅう》マークの**茶《ちゃ》トラのママ**を2回《かい》タップ！"
        case 4: return "**あと1枚《まい》！** 白《しろ》の子猫《こねこ》か招《まね》き猫《ねこ》が来《く》れば勝《か》ち。待《ま》ってみよう。"
        case 5: return "**白《しろ》の子猫《こねこ》**が出《で》た！ 下《した》の**にゃん！**ボタンを押《お》そう"
        default: return ""
        }
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
            } else if canWin(cur.hand) {
                if autoNyan {
                    delay = 0.75
                    action = .tsumo
                }
            } else if cur.riichi, let d = s.drawn {
                // リーチ中は、引いた猫を自動で捨てる
                delay = 0.7
                action = .discard(tileId: d.id)
            }
        case .claim:
            if let head = s.claimQueue.first {
                if !s.players[head].isHuman {
                    delay = 0.52
                    // 練習では CPU は上がらない
                    action = tutorial ? .pass(player: head) : .ron(player: head)
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
        if tutorial {
            // 練習の CPU は上がらず、リーチもしない
            if task == .basics, s.current == 1, !scriptDone, let t = p.hand.first(where: { $0.kind == Tutorial.winKind }) {
                scriptDone = true
                act(.discard(tileId: t.id))
                return
            }
            act(.discard(tileId: chooseDiscard(s, s.current, level: p.level)))
            return
        }
        if var r = cpuRandom {
            // 今日の1局：CPU の迷い方も日付で決める
            let a = chooseAction(s, s.current, level: p.level, rand: { r.nextUnit() })
            cpuRandom = r
            act(a)
            return
        }
        act(chooseAction(s, s.current, level: p.level))
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
