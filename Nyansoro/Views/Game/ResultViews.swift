// 局の結果・試合の結果のカード

import SwiftUI

struct Stamp: View {
    let text: String
    @State private var shown = false

    var body: some View {
        Text(text)
            .font(AppFont.display(32))
            .foregroundColor(Palette.onPink)
            .padding(.horizontal, 22)
            .padding(.vertical, 4)
            .background(Capsule().fill(Palette.pink))
            .background(Capsule().fill(Palette.pinkPress).offset(y: 5))
            .rotationEffect(.degrees(-5))
            .scaleEffect(shown ? 1 : 2.2)
            .opacity(shown ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) { shown = true }
            }
            .accessibilityHidden(true)
    }
}

/// 全員の点数の増減
struct DeltaList: View {
    let state: GameState
    let deltas: [Int]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(0..<state.players.count, id: \.self) { i in
                let p = state.players[i]
                let d = deltas[i]
                HStack(spacing: 8) {
                    Avatar(kind: p.avatar, size: 26)
                    RubyText(p.name, size: 14, bold: true)
                    Spacer(minLength: 0)
                    Text(d > 0 ? "+\(d)" : d < 0 ? "\(d)" : "±0")
                        .font(AppFont.body(14, bold: true))
                        .foregroundColor(d > 0 ? Palette.ok : d < 0 ? Palette.bad : Palette.inkSoft)
                        .monospacedDigit()
                    RubyText("\(p.score)点《てん》", size: 14, bold: true)
                        .frame(minWidth: 60, alignment: .trailing)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(p.isHuman ? Palette.surface : Palette.surface2))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(p.isHuman ? Palette.pink : Palette.line, lineWidth: 2))
            }
        }
        .frame(maxWidth: 380)
    }
}

struct RoundResultCard: View {
    let state: GameState
    let result: RoundResult
    let onNext: () -> Void

    var body: some View {
        ModalCard {
            if result.kind == .exhausted || result.win == nil || result.winner == nil {
                ZStack(alignment: .topTrailing) {
                    CatFace(kind: kindOf(2, 2)).frame(width: 84, height: 84)
                    Text("z z z")
                        .font(AppFont.display(14))
                        .foregroundColor(Palette.inkSoft)
                        .offset(x: 26, y: -4)
                }
                RubyText("お昼寝《ひるね》…", size: 24, display: true, alignment: .center)
                RubyText("山《やま》がなくなって、誰《だれ》も揃《そろ》わなかったよ。", size: 14, alignment: .center)
            } else if let win = result.win, let w = result.winner {
                let winner = state.players[w]
                Stamp(text: "にゃん！")
                RubyText(winner.isHuman ? "キミの勝《か》ち！" : "\(winner.name)の上《あ》がり", size: 22, display: true, alignment: .center)
                RubyText(subtitle, size: 14, alignment: .center)
                FlowLayout(alignment: .center) {
                    ForEach(Array(win.groups.enumerated()), id: \.offset) { item in
                        HStack(spacing: 2) {
                            ForEach(item.element.tiles) { t in
                                TileView(kind: t.kind, width: 40, highlight: t.id == result.tile?.id)
                            }
                        }
                        .padding(.bottom, 9)
                        .overlay(alignment: .bottom) {
                            Capsule().fill(Palette.ok).frame(height: 5).padding(.horizontal, 2)
                        }
                        .padding(6)
                    }
                }
                VStack(spacing: 6) {
                    ForEach(win.items, id: \.self) { item in
                        HStack {
                            RubyText(item.label, size: 14)
                            Spacer(minLength: 0)
                            Text("+\(item.points)")
                                .font(AppFont.body(14, bold: true))
                                .foregroundColor(Palette.ink)
                        }
                    }
                    DashLine()
                        .stroke(Palette.lineStrong, style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                        .frame(height: 2)
                    HStack {
                        RubyText("合計《ごうけい》", size: 16, bold: true)
                        Spacer(minLength: 0)
                        Text("+\(win.total)")
                            .font(AppFont.body(17, bold: true))
                            .foregroundColor(Palette.ink)
                    }
                }
                .frame(maxWidth: 320)
            }
            DeltaList(state: state, deltas: result.deltas)
            Button(action: onNext) {
                RubyText(state.round + 1 >= state.rules.rounds ? "試合《しあい》の結果《けっか》へ" : "次《つぎ》の局《きょく》へ", size: 16, display: true, color: Palette.onPink)
            }
            .buttonStyle(PillButtonStyle(kind: .primary))
        }
    }

    private var subtitle: String {
        if result.kind == .tsumo { return "自分《じぶん》で引《ひ》いて揃《そろ》えた！" }
        let from = result.from.map { state.players[$0].name } ?? ""
        let tile = result.tile.map { kindName($0.kind) } ?? ""
        return "\(from)が捨《す》てた「\(tile)」で揃《そろ》った"
    }
}

struct MatchResultCard: View {
    let state: GameState
    let reward: MatchReward
    let mode: GameMode
    let canOfferReward: Bool
    let onWatchAd: () -> Void
    let onExit: () -> Void
    let onPlay: (GameMode) -> Void

    var body: some View {
        ModalCard {
            switch reward {
            case .tutorial:
                Stamp(text: "クリア！")
                RubyText("練習《れんしゅう》クリア！", size: 22, display: true, alignment: .center)
                RubyText("次《つぎ》は子猫《こねこ》ランクでCPUと対戦《たいせん》しよう。分《わ》からなくなったら、いつでも「？」ボタン。", size: 14, alignment: .center)
                HStack(spacing: 10) {
                    Button(action: onExit) { RubyText("タイトルへ", size: 16, display: true) }
                        .buttonStyle(PillButtonStyle(kind: .ghost))
                    Button { onPlay(.cpu(rank: 0)) } label: { RubyText("CPUと対戦《たいせん》", size: 16, display: true, color: Palette.onPink) }
                        .buttonStyle(PillButtonStyle(kind: .primary))
                }
            case let .practice(place):
                header(place)
                podium
                RubyText("今《いま》より下《した》のランクなので★はなし。今《いま》のランクで★を集《あつ》めよう。", size: 14, alignment: .center)
                buttons(next: nil)
            case let .ranked(place, r):
                header(place)
                podium
                rewardView(r)
                if canOfferReward && !r.rankedUp && !r.crowned {
                    Button(action: onWatchAd) {
                        RubyText("動画《どうが》を見《み》て★をもう1個《こ》", size: 15, display: true, color: Palette.onMint)
                    }
                    .buttonStyle(PillButtonStyle(kind: .secondary))
                }
                buttons(next: r.rankedUp ? .cpu(rank: r.newRank) : nil)
            }
        }
    }

    private func header(_ place: Int) -> some View {
        RubyText(place == 0 ? "やったね！ 1位《い》！" : "キミは\(place + 1)位《い》", size: 24, display: true, alignment: .center)
    }

    private var podium: some View {
        VStack(spacing: 6) {
            ForEach(Array(state.standings.enumerated()), id: \.offset) { item in
                let p = state.players[item.element]
                HStack(spacing: 8) {
                    Text("\(item.offset + 1)")
                        .font(AppFont.display(13))
                        .foregroundColor(item.offset == 0 ? Palette.onGold : Palette.ink)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(item.offset == 0 ? Palette.gold : Palette.lavender))
                    Avatar(kind: p.avatar, size: 26)
                    RubyText(p.name, size: 14, bold: true)
                    Spacer(minLength: 0)
                    RubyText("\(p.score)点《てん》", size: 14, bold: true)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(p.isHuman ? Palette.surface : Palette.surface2))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(p.isHuman ? Palette.pink : Palette.line, lineWidth: 2))
            }
        }
        .frame(maxWidth: 380)
    }

    @ViewBuilder
    private func rewardView(_ r: RankReward) -> some View {
        Text(r.gained > 0 ? "★ +\(r.gained)" : "★はもらえなかった")
            .font(AppFont.display(20))
            .foregroundColor(Palette.goldInk)
        if r.rankedUp {
            VStack(spacing: 4) {
                Text("ランクアップ！")
                    .font(AppFont.display(24))
                    .foregroundColor(Palette.pinkInk)
                RubyText("\(Ranks.all[r.newRank].name)になった！ マット「\(Ranks.all[r.newRank].mat.name)」が使《つか》えるよ", size: 14, alignment: .center)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.surface2))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Palette.goldPress, style: StrokeStyle(lineWidth: 2, dash: [6, 4])))
        } else if r.crowned {
            VStack(spacing: 4) {
                RubyText("王冠《おうかん》ゲット！", size: 24, display: true, color: Palette.pinkInk, alignment: .center)
                RubyText("猫神様《ねこがみさま》に勝《か》った証《あかし》。", size: 14, alignment: .center)
            }
        } else {
            VStack(spacing: 4) {
                HStack(spacing: 2) {
                    ForEach(0..<r.need, id: \.self) { i in
                        Text("★")
                            .font(.system(size: 24))
                            .foregroundColor(i < r.stars ? Palette.goldPress : Palette.lineStrong)
                    }
                }
                RubyText("あと★\(r.need - r.stars)個《こ》で\(r.newRank == Ranks.all.count - 1 ? "王冠《おうかん》" : "ランクアップ")", size: 13, bold: true, alignment: .center)
            }
        }
    }

    private func buttons(next: GameMode?) -> some View {
        HStack(spacing: 10) {
            Button(action: onExit) { RubyText("タイトルへ", size: 16, display: true) }
                .buttonStyle(PillButtonStyle(kind: .ghost))
            Button { onPlay(next ?? mode) } label: {
                RubyText(next == nil ? "もう一度《いちど》" : "次《つぎ》のランクへ", size: 16, display: true, color: Palette.onPink)
            }
            .buttonStyle(PillButtonStyle(kind: .primary))
        }
    }
}
