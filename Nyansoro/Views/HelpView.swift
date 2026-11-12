// 「？」で開く遊び方。ゲーム中は「今の手」も見られる。

import SwiftUI

struct HelpView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case now, win, sets, cats, turn, score, marks, rank
        var id: String { rawValue }

        var label: String {
            switch self {
            case .now: return "今《いま》の手《て》"
            case .win: return "勝《か》ち方《かた》"
            case .sets: return "セット"
            case .cats: return "猫《ねこ》"
            case .turn: return "順番《じゅんばん》"
            case .score: return "点数《てんすう》"
            case .marks: return "マーク"
            case .rank: return "ランク"
            }
        }
    }

    let game: GameState?
    var recommendOn = true
    @Environment(\.dismiss) private var dismiss
    @State private var tab: Tab

    init(game: GameState?, recommendOn: Bool = true) {
        self.game = game
        self.recommendOn = recommendOn
        let inGame = game.map { $0.phase != .matchEnd } ?? false
        _tab = State(initialValue: inGame ? .now : .win)
    }

    private var inGame: Bool { game.map { $0.phase != .matchEnd } ?? false }
    private var tabs: [Tab] { inGame ? Tab.allCases : Tab.allCases.filter { $0 != .now } }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RubyText("遊《あそ》び方《かた》", size: 22, display: true)
                HStack {
                    Spacer()
                    IconButton(icon: .close, label: "閉じる") { dismiss() }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 10)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(tabs) { t in
                        Button { tab = t } label: {
                            RubyText(t.label, size: 14, bold: true, color: tab == t ? Palette.onPink : Palette.ink)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(tab == t ? Palette.pink : Palette.surface))
                                .overlay(Capsule().strokeBorder(tab == t ? Palette.pink : Palette.line, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(plainText(t.label))
                        .accessibilityAddTraits(tab == t ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    content
                }
                .padding(20)
                .frame(maxWidth: 680, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Palette.surface.ignoresSafeArea())
    }

    // MARK: ページ

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .now:
            if let game { NowPage(game: game, recommendOn: recommendOn) }
        case .win:
            RubyText("9枚《まい》で「3枚《まい》セット」を3つ作《つく》ったら勝《か》ち！", size: 17, bold: true)
            FlowLayout {
                example([kindOf(0, 0), kindOf(0, 0), kindOf(0, 0)], "セット1").padding(.trailing, 14)
                example([kindOf(1, 0), kindOf(1, 1), kindOf(1, 2)], "セット2").padding(.trailing, 14)
                example([kindOf(2, 2), kindOf(2, 2), joker], "セット3")
            }
            RubyText("手持《ても》ちは8枚《まい》。自分《じぶん》の番《ばん》に1枚《まい》引《ひ》いて9枚《まい》になったとき、または他《ほか》の人《ひと》が捨《す》てた猫《ねこ》で9枚《まい》が揃《そろ》ったら、**にゃん！**ボタンを押《お》そう。")
        case .sets:
            section("① 同《おな》じ猫《ねこ》")
            RubyText("まったく同《おな》じ猫《ねこ》を3枚《まい》。")
            example([kindOf(3, 1), kindOf(3, 1), kindOf(3, 1)], "茶《ちゃ》トラのママ ×3")
            section("② 家族《かぞく》")
            RubyText("同《おな》じ家族《かぞく》のパパ・ママ・子猫《こねこ》を1枚《まい》ずつ。")
            example([kindOf(4, 0), kindOf(4, 1), kindOf(4, 2)], "サバトラのパパ・ママ・子猫《こねこ》")
            section("招《まね》き猫《ねこ》（2枚《まい》だけ）")
            RubyText("どの猫《ねこ》の代《か》わりにもなれる、すごい猫《ねこ》。")
            example([kindOf(5, 0), joker, kindOf(5, 2)], "招《まね》き猫《ねこ》がハチワレのママの代《か》わり")
            section("これはセットにならないよ")
            HStack(spacing: 10) {
                example([kindOf(0, 0), kindOf(1, 1), kindOf(2, 2)], "家族《かぞく》がバラバラ")
                Text("×")
                    .font(AppFont.display(26))
                    .foregroundColor(Palette.bad)
            }
        case .cats:
            RubyText("猫《ねこ》は6家族《かぞく》×3匹《びき》＝18種類《しゅるい》。それぞれ4枚《まい》ずつあるよ。上《うえ》の帯《おび》の色《いろ》と、毛《け》の模様《もよう》が家族《かぞく》の印《しるし》。")
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Color.clear.frame(width: 1, height: 1)
                    ForEach(0..<3, id: \.self) { r in
                        RubyText(Catalog.roleNames[r], size: 12, bold: true, color: Palette.inkSoft)
                    }
                }
                ForEach(0..<numFamilies, id: \.self) { f in
                    GridRow {
                        RubyText(Catalog.families[f].name, size: 13, bold: true, color: FamilyColors.all[f].ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(FamilyColors.all[f].band))
                        ForEach(0..<3, id: \.self) { r in
                            TileView(kind: kindOf(f, r), width: 46)
                        }
                    }
                }
            }
            RubyText("パパは蝶《ちょう》ネクタイ、ママはリボン、子猫《こねこ》は鈴《すず》を付《つ》けているよ。", size: 13, color: Palette.inkSoft)
        case .turn:
            step(1, "**引《ひ》く：**自分《じぶん》の番《ばん》になると、山《やま》から1枚《まい》引《ひ》くよ（自動《じどう》）。")
            step(2, "**捨《す》てる：**いらない猫《ねこ》をタップして選《えら》び、もう一度《いちど》タップ（または「捨《す》てる」ボタン）で捨《す》てる。")
            step(3, "**にゃん！：**他《ほか》の人《ひと》が捨《す》てた猫《ねこ》で揃《そろ》うときも、にゃん！で勝《か》ち。")
            step(4, "**お昼寝《ひるね》：**山《やま》がなくなったら引《ひ》き分《わ》け。")
            step(5, "1試合《しあい》は**4局《きょく》**。最後《さいご》に点数《てんすう》が一番《いちばん》多《おお》い人《ひと》が1位《い》！")
        case .score:
            VStack(spacing: 6) {
                ForEach(ScoreTable.all, id: \.self) { item in
                    HStack {
                        RubyText(item.label)
                        Spacer(minLength: 0)
                        Text("+\(item.points)")
                            .font(AppFont.body(15, bold: true))
                            .foregroundColor(Palette.ink)
                    }
                }
            }
            .frame(maxWidth: 340)
            RubyText("上《あ》がった人《ひと》だけが点数《てんすう》をもらえる。他《ほか》の人《ひと》の点数《てんすう》は減《へ》らないよ。")
            RubyText("ボス猫《ねこ》ランクから：上《あ》がられる猫《ねこ》を捨《す》てた人《ひと》は −5点《てん》。", size: 13, color: Palette.inkSoft)
        case .marks:
            markRow({
                HStack(spacing: 4) {
                    PawIcon().frame(width: 16, height: 16)
                    Text("にゃん！").font(AppFont.display(14)).foregroundColor(Palette.onGold)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Capsule().fill(Palette.gold))
            }, "揃《そろ》ったときだけ光《ひか》るボタン。押《お》すと勝《か》ち！")
            markRow({ PawIcon().frame(width: 30, height: 30) }, "おすすめの捨《す》てる猫《ねこ》。迷《まよ》ったらこれを捨《す》てよう。")
            markRow({ Capsule().fill(Palette.ok).frame(width: 60, height: 5) }, "緑《みどり》の線《せん》：揃《そろ》ったセット。")
            markRow({
                DashLine()
                    .stroke(Palette.inkSoft.opacity(0.55), style: StrokeStyle(lineWidth: 3, dash: [6, 4]))
                    .frame(width: 60, height: 5)
            }, "点線《てんせん》：あと少《すこ》しで揃《そろ》うセット。")
            markRow({ StatusPill(dist: 1, win: false) }, "あと何枚《なんまい》で揃《そろ》うか。「待《ま》っている猫《ねこ》」が出《で》たら勝《か》ち。")
        case .rank:
            RubyText("CPUとの試合《しあい》で1位《い》なら★2つ、2位《い》なら★1つ。★が貯《た》まるとランクアップ！ ランクは下《さ》がらないよ。")
            ForEach(Array(Ranks.all.enumerated()), id: \.offset) { item in
                let r = item.element
                HStack(alignment: .top, spacing: 12) {
                    Avatar(kind: r.cpus[0].avatar, size: 48)
                    VStack(alignment: .leading, spacing: 4) {
                        RubyText("**\(r.name)**　★\(r.starsToNext)個《こ》で\(r.id == "nekogami" ? "王冠《おうかん》" : "ランクアップ")", size: 15)
                        RubyText(r.blurb, size: 13, color: Palette.inkSoft)
                        RubyText("ご褒美《ほうび》：マット「\(r.mat.name)」", size: 13, color: Palette.inkSoft)
                    }
                }
            }
        }
    }

    private func section(_ title: String) -> some View {
        RubyText(title, size: 17, display: true)
            .padding(.top, 8)
    }

    private func example(_ kinds: [Int], _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                ForEach(Array(kinds.enumerated()), id: \.offset) { item in
                    TileView(kind: item.element, width: 46)
                }
            }
            RubyText(label, size: 12, bold: true, color: Palette.inkSoft)
        }
        .padding(.bottom, 6)
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)")
                .font(AppFont.display(14))
                .foregroundColor(Palette.onPink)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Palette.pink))
            RubyText(text)
        }
    }

    private func markRow<Mark: View>(@ViewBuilder _ mark: () -> Mark, _ text: String) -> some View {
        HStack(spacing: 14) {
            mark()
                .frame(minWidth: 70)
            RubyText(text)
            Spacer(minLength: 0)
        }
    }
}

/// 「今の手」：揃ったセット・足りない猫・待っている猫
private struct NowPage: View {
    let game: GameState
    let recommendOn: Bool

    var body: some View {
        let a = arrange(game.players[0].hand)
        let info = handInsight(game, seat: 0, recommendOn: recommendOn)
        VStack(alignment: .leading, spacing: 12) {
            RubyText("今《いま》のキミの手《て》", size: 17, display: true)
            FlowLayout {
                ForEach(Array(a.groups.enumerated()), id: \.offset) { item in
                    let g = item.element
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { j in
                            if let t = g.slots[j] {
                                TileView(kind: t.kind, width: 42)
                            } else {
                                CatFace(kind: g.slotKinds[j])
                                    .opacity(0.35)
                                    .padding(3)
                                    .frame(width: 42, height: 42 * 1.34)
                                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.lineStrong, style: StrokeStyle(lineWidth: 2, dash: [4, 3])))
                                    .accessibilityLabel(plainText(kindName(g.slotKinds[j])) + "が足りない")
                            }
                        }
                    }
                    .padding(.bottom, 9)
                    .overlay(alignment: .bottom) {
                        if g.complete {
                            Capsule().fill(Palette.ok).frame(height: 5)
                        } else {
                            DashLine().stroke(Palette.inkSoft.opacity(0.55), style: StrokeStyle(lineWidth: 3, dash: [6, 4])).frame(height: 5)
                        }
                    }
                    .padding(.trailing, 10)
                    .padding(.bottom, 8)
                }
                if !a.leftovers.isEmpty {
                    HStack(spacing: 3) {
                        ForEach(a.leftovers) { t in TileView(kind: t.kind, width: 42) }
                    }
                    .padding(.bottom, 17)
                }
            }
            RubyText("緑《みどり》の線《せん》＝揃《そろ》ったセット。点線《てんせん》＝あと少《すこ》しのセット。薄《うす》い猫《ねこ》＝足《た》りない猫《ねこ》。", size: 13, color: Palette.inkSoft)

            if let info {
                RubyText("状況《じょうきょう》", size: 17, display: true)
                if info.canWin {
                    RubyText("**揃《そろ》ってる！ にゃん！ボタンを押《お》そう**", size: 16)
                } else {
                    RubyText("\(info.afterDiscard ? "おすすめを捨《す》てると、" : "")あと**\(info.dist)**枚《まい》で揃《そろ》うよ", size: 16)
                }
                if let rec = info.rec {
                    HStack(spacing: 8) {
                        RubyText("おすすめ：", bold: true)
                        TileView(kind: rec, width: 42, recommended: true)
                        RubyText("\(kindName(rec))を捨《す》てる", bold: true)
                    }
                }
                if !info.waits.isEmpty {
                    HStack(spacing: 8) {
                        RubyText("待《ま》っている猫《ねこ》：", bold: true)
                        ForEach(info.waits, id: \.self) { k in
                            VStack(spacing: 2) {
                                TileView(kind: k, width: 42)
                                RubyText("残《のこ》り\(info.unseen[k])", size: 11, color: Palette.inkSoft)
                            }
                        }
                    }
                }
            }
        }
    }
}
