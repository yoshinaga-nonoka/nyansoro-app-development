// 対戦画面。上：相手3人と卓（座布団）、下：自分の手札のトレイ。
// iPad など横幅が広いときは、相手を卓の左・上・右に並べる。

import SwiftUI

struct GameView: View {
    @ObservedObject var app: AppModel
    @StateObject private var game: GameController

    init(mode: GameMode, app: AppModel) {
        self.app = app
        _game = StateObject(wrappedValue: GameController(mode: mode, app: app))
    }

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var wideScreen: Bool { sizeClass == .regular }

    var body: some View {
        GeometryReader { geo in
            let width = min(geo.size.width, 920)
            ViewThatFits(in: .vertical) {
                screen(width: width)
                    .frame(minHeight: geo.size.height)
                ScrollView(.vertical, showsIndicators: false) {
                    screen(width: width)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .background(Palette.bg.ignoresSafeArea())
        .overlay { overlays }
        .sheet(isPresented: $game.showHelp) {
            HelpView(game: game.state, recommendOn: game.recommendOn)
                .environment(\.furigana, app.settings.furigana)
        }
        .sheet(isPresented: $game.showSettings) {
            SettingsView(app: app, allowReset: false)
                .environment(\.furigana, app.settings.furigana)
        }
    }

    private func screen(width: CGFloat) -> some View {
        VStack(spacing: 10) {
            topBar(compact: width < 420)
            table(width: width)
                .frame(maxHeight: .infinity)
            tray(width: width)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: 920)
    }

    // MARK: 上のバー

    private func topBar(compact: Bool) -> some View {
        HStack(spacing: 8) {
            IconButton(icon: .back, label: "試合をやめる") { game.showQuit = true }
            if !compact {
                RubyText(game.titleText, size: 17, display: true)
                    .fixedSize()
            }
            Spacer(minLength: 0)
            RoundDots(round: game.state.round, total: game.state.rules.rounds)
            IconButton(icon: .settings, label: "設定") { game.showSettings = true }
            HelpButton { game.showHelp = true }
        }
    }

    // MARK: 卓

    private func table(width: CGFloat) -> some View {
        let mat = app.settings.mat.style
        let wide = width >= 700
        let pondTile: CGFloat = width >= 700 ? 34 : width >= 640 ? 28 : 22
        let lastId = game.state.lastDiscard?.tile.id
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        return VStack(spacing: 10) {
            if wide {
                HStack(alignment: .top, spacing: 10) {
                    seat(1, pondTile: pondTile, lastId: lastId)
                        .frame(width: width * 0.27)
                        .frame(maxHeight: .infinity, alignment: .top)
                    VStack(spacing: 10) {
                        seat(2, pondTile: pondTile, lastId: lastId)
                        center
                            .frame(maxHeight: .infinity)
                    }
                    seat(3, pondTile: pondTile, lastId: lastId)
                        .frame(width: width * 0.27)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            } else {
                HStack(alignment: .top, spacing: 8) {
                    seat(1, pondTile: pondTile, lastId: lastId)
                    seat(2, pondTile: pondTile, lastId: lastId)
                    seat(3, pondTile: pondTile, lastId: lastId)
                }
                center
                    .frame(maxHeight: .infinity)
            }
            myPond(pondTile: pondTile, lastId: lastId)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(shape.fill(mat.fill))
        .overlay(shape.strokeBorder(mat.edge, lineWidth: 3))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Palette.matStitch, style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                .padding(6)
                .allowsHitTesting(false)
        )
        .overlay {
            if let banner = game.banner {
                bannerView(banner)
                    .clipShape(shape)
            }
        }
        .shadow(color: Palette.shadow, radius: 14, x: 0, y: 8)
    }

    private func seat(_ i: Int, pondTile: CGFloat, lastId: Int?) -> some View {
        let s = game.state
        return SeatView(player: s.players[i], active: s.current == i && (s.phase == .draw || s.phase == .discard), lastId: lastId, pondTile: pondTile)
    }

    private var center: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                WallStack()
                RubyText("山《やま》", size: 12, bold: true, color: Palette.matInkSoft)
                Text("\(game.state.wall.count)")
                    .font(AppFont.body(14, bold: true))
                    .foregroundColor(Palette.matInk)
                    .monospacedDigit()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Capsule().fill(Palette.matPanel))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("山 残り\(game.state.wall.count)枚")

            centerInfo
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var centerInfo: some View {
        let s = game.state
        if s.phase == .claim, let ld = s.lastDiscard {
            HStack(spacing: 12) {
                TileView(kind: ld.tile.kind, width: wideScreen ? 58 : 44, highlight: true)
                VStack(alignment: .leading, spacing: 4) {
                    RubyText("\(s.players[ld.from].name)が「\(kindName(ld.tile.kind))」を捨《す》てた", size: 13, bold: true, color: Palette.matInk)
                    RubyText(game.myClaim ? "揃《そろ》う！ にゃん！で勝《か》ち" : "\(s.players[s.claimQueue.first ?? 0].name)が…！", size: 17, display: true, color: game.myClaim ? Palette.goldInk : Palette.matInk)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.matPanelStrong))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(game.myClaim ? Palette.goldPress : Color.clear, lineWidth: 3))
        } else if s.phase == .draw || s.phase == .discard {
            VStack(spacing: 8) {
                if let ld = s.lastDiscard {
                    HStack(spacing: 8) {
                        TileView(kind: ld.tile.kind, width: wideScreen ? 54 : 40)
                        RubyText("\(s.players[ld.from].name)が捨《す》てた", size: 12, bold: true, color: Palette.matInkSoft)
                    }
                }
                let isMe = s.current == 0
                HStack(spacing: 8) {
                    Avatar(kind: s.players[s.current].avatar, size: 28)
                    RubyText(isMe ? "キミの番《ばん》！" : "\(s.players[s.current].name)の番《ばん》", size: 17, display: true, color: isMe ? Palette.onGold : Palette.matInk)
                }
                .padding(.leading, 4)
                .padding(.trailing, 16)
                .padding(.vertical, 4)
                .background(Capsule().fill(isMe ? Palette.gold : Palette.matPanelStrong))
                .background(Capsule().fill(isMe ? Palette.goldPress : Color.clear).offset(y: 3))
            }
        }
    }

    private func myPond(pondTile: CGFloat, lastId: Int?) -> some View {
        HStack(alignment: .center, spacing: 8) {
            RubyText("キミが捨《す》てた", size: 11, bold: true, color: Palette.matInkSoft)
                .fixedSize()
            FlowLayout {
                ForEach(game.me.discards) { t in
                    TileView(kind: t.kind, width: pondTile, highlight: t.id == lastId)
                        .padding(.trailing, 3)
                        .padding(.bottom, 4)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(minHeight: 44)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.matPanel))
    }

    private func bannerView(_ text: String) -> some View {
        ZStack {
            Palette.overlay
            VStack(spacing: 8) {
                RubyText(text, size: 34, display: true)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Palette.surface))
                    .background(Capsule().fill(Palette.lineStrong).offset(y: 6))
                RubyText("\(game.state.players[game.state.dealer].name)からスタート", size: 13, bold: true, color: Palette.inkSoft)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Palette.surface))
            }
        }
        .transition(.opacity)
    }

    // MARK: 自分のトレイ

    private func tray(width: CGFloat) -> some View {
        let d = game.derived
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                Avatar(kind: game.me.avatar, size: 32)
                if width >= 420 {
                    RubyText("キミ", size: 14, bold: true)
                }
                RubyText("\(game.me.score)点《てん》", size: 15, bold: true)
                Spacer(minLength: 0)
                if game.hints, let ins = d.insight {
                    StatusPill(dist: ins.dist, win: game.myClaim || ins.canWin)
                }
            }
            .padding(.horizontal, 4)

            coach(d)
            hand(d, width: width)
            actions
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(shape.fill(Palette.surface))
        .overlay(shape.strokeBorder(game.myDiscardTurn ? Palette.goldPress : Palette.line, lineWidth: game.myDiscardTurn ? 3 : 2))
        .shadow(color: Palette.shadow, radius: 14, x: 0, y: 8)
    }

    private func coach(_ d: GameController.Derived) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return HStack(spacing: 8) {
            if game.tutorial {
                RubyText(game.nudge ?? tutorialLine(game.tStep), size: 14)
                Spacer(minLength: 0)
                if game.tutorialGate {
                    Button { game.tutorialNext() } label: {
                        RubyText("次《つぎ》へ", size: 14, display: true, color: Palette.onPink)
                    }
                    .buttonStyle(PillButtonStyle(kind: .small))
                }
            } else {
                coachContent(d)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(shape.fill(game.tutorial ? Palette.surface : Palette.surface2))
        .overlay(shape.strokeBorder(game.tutorial ? Palette.pink : Palette.line, lineWidth: 2))
    }

    @ViewBuilder
    private func coachContent(_ d: GameController.Derived) -> some View {
        if game.myClaim, let t = game.state.lastDiscard?.tile {
            RubyText("**「\(kindName(t.kind))」で揃《そろ》う！ にゃん！で勝《か》ち**", size: 14)
        } else if game.myDraw {
            RubyText("キミの番《ばん》。山《やま》から1枚《まい》引《ひ》くよ", size: 14)
        } else if !game.hints {
            RubyText(game.myDiscardTurn ? "キミの番《ばん》。1枚《まい》捨《す》てよう" : "他《ほか》の人《ひと》の番《ばん》", size: 14)
        } else if let ins = d.insight {
            if game.myDiscardTurn && ins.canWin {
                RubyText("**揃《そろ》った！ にゃん！を押《お》そう**", size: 14)
            } else if game.myDiscardTurn && ins.rec != nil {
                HStack(spacing: 4) {
                    PawIcon().frame(width: 20, height: 20)
                    RubyText(ins.dist == 1 ? "を捨《す》てると**あと1枚《まい》！**\(pointsText(d.waitPoints))" : "がおすすめ。いらない猫《ねこ》を捨《す》てよう", size: 14)
                }
            } else if game.myDiscardTurn {
                RubyText("いらない猫《ねこ》を1枚《まい》捨《す》てよう", size: 14)
            } else if ins.dist == 1 {
                HStack(spacing: 8) {
                    RubyText("待《ま》ってる猫《ねこ》", size: 12, bold: true, color: Palette.inkSoft)
                        .fixedSize()
                    ForEach(ins.waits, id: \.self) { k in
                        HStack(alignment: .bottom, spacing: 2) {
                            TileView(kind: k, width: 20)
                            Text("\(ins.unseen[k])")
                                .font(AppFont.body(11, bold: true))
                                .foregroundColor(Palette.inkSoft)
                        }
                    }
                    if let p = d.waitPoints {
                        RubyText(p.min == p.max ? "\(p.max)点《てん》" : "\(p.min)〜\(p.max)点《てん》", size: 13, bold: true, color: Palette.goldInk)
                            .fixedSize()
                    }
                }
            } else {
                RubyText("他《ほか》の人《ひと》の番《ばん》。捨《す》てられた猫《ねこ》もチェックしよう", size: 14)
            }
        }
    }

    /// 「上がれば◯〜◯点」（点数を意識してもらうため）
    private func pointsText(_ p: (min: Int, max: Int)?) -> String {
        guard let p else { return "" }
        return p.min == p.max ? "　上《あ》がれば\(p.max)点《てん》" : "　上《あ》がれば\(p.min)〜\(p.max)点《てん》"
    }

    private func tutorialLine(_ step: Int) -> String {
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

    private func hand(_ d: GameController.Derived, width: CGFloat) -> some View {
        let tw = max(28, min(width >= 700 ? 84 : 64, (width - 32 - 20 - 48) / 9))
        return HStack(alignment: .bottom, spacing: width >= 640 ? 9 : 5) {
            if let a = d.arrangement {
                ForEach(Array(a.groups.enumerated()), id: \.offset) { item in
                    handGroup(item.element.tiles, line: item.element.complete ? .complete : .partial, tw: tw, rec: d.recTileId)
                }
                if !a.leftovers.isEmpty {
                    handGroup(a.leftovers, line: .none, tw: tw, rec: d.recTileId)
                }
            } else {
                handGroup(sortTiles(d.baseTiles), line: .none, tw: tw, rec: d.recTileId)
            }
            if let drawn = d.drawnTile {
                VStack(spacing: 2) {
                    RubyText("引《ひ》いた", size: 10, bold: true, color: Palette.pinkInk)
                        .fixedSize()
                    handTile(drawn, tw: tw, rec: d.recTileId)
                        .padding(.bottom, 9)
                }
                .padding(.leading, 5)
            }
        }
        .padding(.top, 22)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("キミの手")
    }

    private enum Underline {
        case complete, partial, none
    }

    private func handGroup(_ tiles: [Tile], line: Underline, tw: CGFloat, rec: Int?) -> some View {
        HStack(spacing: 2) {
            ForEach(tiles) { t in
                handTile(t, tw: tw, rec: rec)
            }
        }
        .padding(.bottom, 9)
        .overlay(alignment: .bottom) {
            switch line {
            case .complete:
                Capsule().fill(Palette.ok).frame(height: 5).padding(.horizontal, 2)
            case .partial:
                DashLine()
                    .stroke(Palette.inkSoft.opacity(0.55), style: StrokeStyle(lineWidth: 3, dash: [6, 4]))
                    .frame(height: 5)
                    .padding(.horizontal, 2)
            case .none:
                EmptyView()
            }
        }
    }

    private func handTile(_ t: Tile, tw: CGFloat, rec: Int?) -> some View {
        Button {
            game.tapTile(t)
        } label: {
            TileView(kind: t.kind, width: tw, selected: game.selectedId == t.id, recommended: rec == t.id)
        }
        .buttonStyle(.plain)
    }

    private var actions: some View {
        HStack(spacing: 10) {
            if game.myClaim {
                NyanButton { game.act(.ron(player: 0)) }
                if !game.tutorial {
                    Button { game.act(.pass(player: 0)) } label: {
                        RubyText("見逃《みのが》す", size: 16, display: true)
                    }
                    .buttonStyle(PillButtonStyle(kind: .ghost))
                }
            }
            if game.canTsumo {
                NyanButton { game.act(.tsumo) }
            }
            if game.myDiscardTurn, let sel = game.selectedTile {
                Button { game.discard(sel) } label: {
                    RubyText("「\(kindName(sel.kind))」を捨《す》てる", size: 15, display: true, color: Palette.onPink)
                }
                .buttonStyle(PillButtonStyle(kind: .primary))
            }
            if game.myDiscardTurn && game.selectedTile == nil && !game.canTsumo {
                RubyText("捨《す》てる猫《ねこ》をタップしてね", size: 13, bold: true, color: Palette.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 56)
    }

    // MARK: 結果・確認

    @ViewBuilder
    private var overlays: some View {
        let s = game.state
        if s.phase == .roundEnd, let r = s.result, !game.showHelp, !game.showSettings {
            RoundResultCard(state: s, result: r, missions: game.roundMissions) { game.nextRound() }
        } else if s.phase == .matchEnd, let reward = game.reward {
            MatchResultCard(
                state: s,
                reward: reward,
                mode: game.mode,
                canOfferReward: app.canOfferReward,
                onWatchAd: { game.watchAdForStar() },
                currentRank: app.save.progress.rank,
                review: game.review,
                askReminders: !app.save.askedReminders,
                onEnableReminders: { app.enableReminders() },
                onExit: { app.leaveMatch { app.showTitle() } },
                onPlay: { next in app.leaveMatch { app.play(next) } },
                onLesson: { app.showLesson = true }
            )
        }
        if game.showQuit {
            ModalCard(maxWidth: 420) {
                RubyText("途中《とちゅう》でやめる？", size: 22, display: true, alignment: .center)
                RubyText(game.tutorial ? "練習《れんしゅう》はいつでもやり直《なお》せるよ。" : "この試合《しあい》の★はもらえないよ。", size: 14, alignment: .center)
                HStack(spacing: 10) {
                    Button { app.showTitle() } label: { RubyText("やめる", size: 16, display: true) }
                        .buttonStyle(PillButtonStyle(kind: .ghost))
                    Button { game.showQuit = false } label: { RubyText("続《つづ》ける", size: 16, display: true, color: Palette.onPink) }
                        .buttonStyle(PillButtonStyle(kind: .primary))
                }
            }
        }
    }
}

// MARK: - 部品

struct SeatView: View {
    let player: PlayerState
    let active: Bool
    let lastId: Int?
    let pondTile: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Avatar(kind: player.avatar, size: 30)
                VStack(alignment: .leading, spacing: 0) {
                    RubyText(player.name, size: 13, bold: true, color: Palette.matInk)
                    RubyText("\(player.score)点《てん》", size: 11, color: Palette.matInkSoft)
                }
                Spacer(minLength: 0)
                if active { ThinkingDots() }
            }
            TileBacks(count: player.hand.count)
            FlowLayout {
                ForEach(player.discards) { t in
                    TileView(kind: t.kind, width: pondTile, highlight: t.id == lastId)
                        .padding(.trailing, 3)
                        .padding(.bottom, 4)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(shape.fill(active ? Palette.matPanelStrong : Palette.matPanel))
        .overlay(shape.strokeBorder(active ? Palette.goldPress : Color.clear, lineWidth: 2))
        .offset(y: active ? -2 : 0)
        .animation(.easeOut(duration: 0.2), value: active)
        .accessibilityElement(children: .combine)
    }
}

struct ThinkingDots: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Palette.goldPress)
                    .frame(width: 5, height: 5)
                    .opacity(phase == i ? 1 : 0.35)
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 300_000_000)
                phase = (phase + 1) % 3
            }
        }
        .accessibilityLabel("考え中")
    }
}

struct WallStack: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(i % 2 == 0 ? Palette.back : Palette.back2)
                    .frame(width: 12, height: 15)
                    .offset(x: CGFloat(2 - i) * 2, y: CGFloat(i - 2) * 2)
            }
        }
        .frame(width: 18, height: 19)
        .accessibilityHidden(true)
    }
}

struct RoundDots: View {
    let round: Int
    let total: Int

    var body: some View {
        let now = min(round, total - 1)
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                ForEach(0..<total, id: \.self) { i in
                    Circle()
                        .fill(i < now ? Palette.mintPress : i == now ? Palette.pinkPress : Palette.lineStrong)
                        .frame(width: 9, height: 9)
                        .overlay(Circle().stroke(i == now ? Palette.pink : Color.clear, lineWidth: 3).padding(-3))
                }
            }
            RubyText("\(now + 1)局目《きょくめ》", size: 12, bold: true)
                .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Capsule().fill(Palette.surface))
        .overlay(Capsule().strokeBorder(Palette.line, lineWidth: 2))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(now + 1)局目 / 全\(total)局")
    }
}

struct StatusPill: View {
    let dist: Int
    let win: Bool

    var body: some View {
        let one = !win && dist == 1
        RubyText(win ? "揃《そろ》った！" : "あと\(dist)枚《まい》\(one ? "！" : "")", size: 14, display: true, color: win ? Palette.onGold : one ? Palette.onPink : Palette.ink)
            .fixedSize()
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .background(Capsule().fill(win ? Palette.gold : one ? Palette.pink : Palette.lavender))
    }
}

struct NyanButton: View {
    let action: () -> Void
    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                PawIcon().frame(width: 24, height: 24)
                Text("にゃん！")
            }
        }
        .buttonStyle(PillButtonStyle(kind: .nyan))
        .scaleEffect(pulse ? 1.06 : 1)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}
