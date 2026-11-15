// 局の結果・試合の結果のカード

import SwiftUI

struct Stamp: View {
    let text: String
    @State private var shown = false

    var body: some View {
        Text(text)
            .font(AppFont.display(26))
            .foregroundColor(Palette.onPink)
            .padding(.horizontal, 20)
            .padding(.vertical, 2)
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
                    Avatar(kind: p.avatar, size: 24)
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
                .padding(.vertical, 4)
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
    var missions: [MissionDef] = []
    let onNext: () -> Void

    var body: some View {
        ModalCard(spacing: 10) {
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
                feedback
            } else if let win = result.win, let w = result.winner {
                let winner = state.players[w]
                Stamp(text: "にゃん！")
                RubyText(winner.isHuman ? "キミの勝《か》ち！" : "\(winner.name)の上《あ》がり", size: 20, display: true, alignment: .center)
                RubyText(subtitle, size: 13, alignment: .center)
                feedback
                FlowLayout(alignment: .center) {
                    ForEach(Array(win.groups.enumerated()), id: \.offset) { item in
                        HStack(spacing: 2) {
                            ForEach(item.element.tiles) { t in
                                TileView(kind: t.kind, width: 30, highlight: t.id == result.tile?.id)
                            }
                        }
                        .padding(.bottom, 8)
                        .overlay(alignment: .bottom) {
                            Capsule().fill(Palette.ok).frame(height: 4).padding(.horizontal, 2)
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 4)
                    }
                }
                VStack(spacing: 2) {
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
            if !missions.isEmpty {
                MissionChips(missions: missions)
            }
            DeltaList(state: state, deltas: result.deltas)
            Button(action: onNext) {
                RubyText(state.round + 1 >= state.rules.rounds ? "試合《しあい》の結果《けっか》へ" : "次《つぎ》の局《きょく》へ", size: 16, display: true, color: Palette.onPink)
            }
            .buttonStyle(PillButtonStyle(kind: .primary))
        }
    }

    /// 惜しかったとき・上がったときの一言
    @ViewBuilder
    private var feedback: some View {
        if let message = Feedback.roundMessage(state) {
            RubyText(message, size: 15, display: true, color: result.winner == 0 ? Palette.goldInk : Palette.pinkInk, alignment: .center)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(result.winner == 0 ? Palette.gold.opacity(0.35) : Palette.pink.opacity(0.3)))
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
    var currentRank = 0
    var review: MatchReview?
    var askReminders = false
    var onEnableReminders: () -> Void = {}
    let onExit: () -> Void
    let onPlay: (GameMode) -> Void
    var onLesson: () -> Void = {}

    var body: some View {
        ModalCard(spacing: 10) {
            switch reward {
            case .tutorial:
                Stamp(text: "クリア！")
                RubyText("練習《れんしゅう》クリア！", size: 22, display: true, alignment: .center)
                RubyText("次《つぎ》は「上達《じょうたつ》レッスン」で、点数《てんすう》の稼《かせ》ぎ方《かた》とランクアップの道《みち》を見《み》てみよう。", size: 14, alignment: .center)
                Button(action: onLesson) {
                    RubyText("上達《じょうたつ》レッスンを見《み》る", size: 16, display: true, color: Palette.onGold)
                }
                .buttonStyle(PillButtonStyle(kind: .nyan))
                HStack(spacing: 10) {
                    Button(action: onExit) { RubyText("タイトルへ", size: 16, display: true) }
                        .buttonStyle(PillButtonStyle(kind: .ghost))
                    Button { onPlay(.cpu(rank: 0)) } label: { RubyText("CPUと対戦《たいせん》", size: 16, display: true, color: Palette.onPink) }
                        .buttonStyle(PillButtonStyle(kind: .primary))
                }
            case let .daily(d):
                if d.won { Stamp(text: "クリア！") }
                RubyText(d.won ? "今日《きょう》の1局《きょく》クリア！" : "今日《きょう》の1局《きょく》、残念《ざんねん》…", size: 22, display: true, alignment: .center)
                RubyText(d.won ? "\(d.turns)巡目《じゅんめ》で上《あ》がり・\(d.points)点《てん》" : "また明日《あした》、新《あたら》しい配牌《はいぱい》で挑戦《ちょうせん》しよう", size: 14, alignment: .center)
                StreakBadge(count: d.streak, big: true)
                if let review { ReviewSection(review: review) }
                if let r = d.star {
                    rewardView(r)
                }
                if askReminders {
                    VStack(spacing: 6) {
                        RubyText("毎日《まいにち》19時《じ》に、今日《きょう》の1局《きょく》をお知《し》らせする？", size: 13, alignment: .center)
                        Button(action: onEnableReminders) {
                            RubyText("お知《し》らせを受《う》け取《と》る", size: 15, display: true, color: Palette.onMint)
                        }
                        .buttonStyle(PillButtonStyle(kind: .secondary))
                    }
                }
                HStack(spacing: 10) {
                    Button(action: onExit) { RubyText("タイトルへ", size: 16, display: true) }
                        .buttonStyle(PillButtonStyle(kind: .ghost))
                    Button { onPlay(.cpu(rank: currentRank)) } label: {
                        RubyText("CPUと対戦《たいせん》", size: 16, display: true, color: Palette.onPink)
                    }
                    .buttonStyle(PillButtonStyle(kind: .primary))
                }
            case let .practice(place):
                header(place)
                podium
                RubyText("今《いま》より下《した》のランクなので★はなし。今《いま》のランクで★を集《あつ》めよう。", size: 14, alignment: .center)
                if let review { ReviewSection(review: review) }
                buttons(next: nil)
            case let .ranked(place, r):
                header(place)
                podium
                rewardView(r)
                if let review { ReviewSection(review: review) }
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
        RubyText(place == 0 ? "やったね！ 1位《い》！" : "キミは\(place + 1)位《い》", size: 21, display: true, alignment: .center)
    }

    private var podium: some View {
        VStack(spacing: 6) {
            ForEach(Array(state.standings.enumerated()), id: \.offset) { item in
                let p = state.players[item.element]
                HStack(spacing: 8) {
                    Text("\(item.offset + 1)")
                        .font(AppFont.display(13))
                        .foregroundColor(item.offset == 0 ? Palette.onGold : Palette.ink)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(item.offset == 0 ? Palette.gold : Palette.lavender))
                    Avatar(kind: p.avatar, size: 22)
                    RubyText(p.name, size: 13, bold: true)
                    Spacer(minLength: 0)
                    RubyText("\(p.score)点《てん》", size: 13, bold: true)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 3)
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
                RubyText("\(Ranks.all[r.newRank].name)になった！ マット「\(Ranks.all[r.newRank].mat.name)」が使《つか》えるよ", size: 13, alignment: .center)
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
                            .font(.system(size: 18))
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

/// 連続日数の印（炎のマーク＋日数）
struct StreakBadge: View {
    let count: Int
    var big = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: big ? 22 : 15, weight: .bold))
                .foregroundColor(count > 0 ? Color(hex: 0xF08A3C) : Palette.lineStrong)
            Text("\(count)")
                .font(AppFont.display(big ? 24 : 16))
                .foregroundColor(Palette.ink)
            RubyText("日《にち》連続《れんぞく》", size: big ? 14 : 12, bold: true, color: Palette.inkSoft)
                .fixedSize()
        }
        .padding(.horizontal, big ? 16 : 10)
        .padding(.vertical, big ? 6 : 3)
        .background(Capsule().fill(Palette.gold.opacity(count > 0 ? 0.45 : 0.15)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count)日連続")
    }
}

/// 試合のあとのふりかえり：捨て方の正確さ・一言・達成した目標
struct ReviewSection: View {
    let review: MatchReview

    var body: some View {
        let t = review.tally
        VStack(alignment: .leading, spacing: 6) {
            RubyText("ふりかえり", size: 15, display: true)
            if t.total > 0 {
                HStack {
                    RubyText("ベストな捨《す》て方《かた》", size: 13, bold: true)
                    Spacer(minLength: 0)
                    Text("\(t.best)/\(t.total)（\(Int((t.accuracy * 100).rounded()))%）")
                        .font(AppFont.body(14, bold: true))
                        .foregroundColor(Palette.ink)
                        .monospacedDigit()
                }
                MeterBar(value: t.accuracy, color: t.accuracy >= 0.9 ? Palette.ok : t.accuracy >= 0.7 ? Palette.goldPress : Palette.pinkPress)
                if t.miss > 0 {
                    RubyText("遠回《とおまわ》りの捨《す》て方《かた》 \(t.miss)回《かい》", size: 12, color: Palette.inkSoft)
                }
            }
            RubyText(review.tip, size: 13)
            if !review.missions.isEmpty {
                MissionChips(missions: review.missions.map { Missions.def($0) })
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 380, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.surface2))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.line, lineWidth: 2))
    }
}

/// 横棒のメーター（0〜1）
struct MeterBar: View {
    let value: Double
    var color: Color = Palette.ok

    var body: some View {
        Capsule()
            .fill(Palette.line)
            .frame(height: 8)
            .overlay(alignment: .leading) {
                GeometryReader { g in
                    Capsule().fill(color).frame(width: max(8, g.size.width * min(1, max(0, value))))
                }
            }
            .accessibilityHidden(true)
    }
}

/// 達成した目標（称号）の印
struct MissionChips: View {
    let missions: [MissionDef]

    var body: some View {
        FlowLayout(alignment: .center) {
            ForEach(missions) { m in
                HStack(spacing: 4) {
                    Image(systemName: "rosette")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Palette.goldInk)
                    RubyText("目標達成《もくひょうたっせい》：\(m.badge)", size: 12, bold: true)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Palette.gold.opacity(0.45)))
                .padding(3)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("目標達成：" + missions.map { plainText($0.badge) }.joined(separator: "、"))
    }
}
