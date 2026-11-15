// 上達レッスン：点数の稼ぎ方・強くなるコツ・ランクアップの道。
// 練習のあとに出し、「？」の「上達」タブとタイトルからも見られる。

import SwiftUI

struct LessonView: View {
    @EnvironmentObject var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0
    private let pages = 3

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RubyText("上達《じょうたつ》レッスン", size: 22, display: true)
                HStack {
                    Spacer()
                    IconButton(icon: .close, label: "閉じる") { dismiss() }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 6)

            TabView(selection: $page) {
                lessonPage { LessonPointsPage() }.tag(0)
                lessonPage { LessonTipsPage() }.tag(1)
                lessonPage {
                    LessonRanksPage(currentRank: app.save.progress.rank) {
                        dismiss()
                        app.showMissions = true
                    }
                }
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < pages - 1 {
                    withAnimation { page += 1 }
                } else {
                    dismiss()
                }
            } label: {
                RubyText(page < pages - 1 ? "次《つぎ》へ" : "対戦《たいせん》で試《ため》してみよう", size: 16, display: true, color: Palette.onPink)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PillButtonStyle(kind: .primary))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Palette.surface.ignoresSafeArea())
    }

    private func lessonPage<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) { content() }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 44)
                .frame(maxWidth: 640, alignment: .leading)
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - ① 点数

struct LessonPointsPage: View {
    private struct Example {
        let kinds: [Int]
        let tsumo: Bool
        let note: String
    }

    private let examples: [Example] = [
        Example(kinds: [0, 0, 0, 3, 4, 5, 8, 8, joker], tsumo: false, note: "人《ひと》が捨《す》てた猫《ねこ》で、招《まね》き猫《ねこ》を使《つか》って上《あ》がり"),
        Example(kinds: [0, 0, 0, 3, 4, 5, 8, 8, 8], tsumo: true, note: "自分《じぶん》で引《ひ》いて、招《まね》き猫《ねこ》なし"),
        Example(kinds: [0, 1, 2, 3, 4, 5, 6, 7, 8], tsumo: false, note: "全部《ぜんぶ》家族《かぞく》で、招《まね》き猫《ねこ》なし"),
        Example(kinds: [0, 0, 0, 3, 3, 3, 6, 6, 6], tsumo: true, note: "全部《ぜんぶ》同《おな》じ猫《ねこ》＋招《まね》き猫《ねこ》なし＋自分《じぶん》で引《ひ》く"),
    ]

    var body: some View {
        RubyText("① 点数《てんすう》の稼《かせ》ぎ方《かた》", size: 19, display: true)
        RubyText("上《あ》がるだけで**10点《てん》**。ボーナスを重《かさ》ねると**最大《さいだい》30点《てん》**！ 1位《い》になるには、速《はや》く上《あ》がるか、高《たか》い点《てん》で上《あ》がるか。", size: 14)
        VStack(spacing: 4) {
            ForEach(ScoreTable.all, id: \.self) { item in
                HStack {
                    RubyText(item.label, size: 14)
                    Spacer(minLength: 0)
                    Text("+\(item.points)")
                        .font(AppFont.body(15, bold: true))
                        .foregroundColor(Palette.ink)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.surface2))
        RubyText("「全部《ぜんぶ》同《おな》じ猫《ねこ》」と「全部《ぜんぶ》家族《かぞく》」は、どちらか一方《いっぽう》だけ。", size: 12, color: Palette.inkSoft)

        ForEach(Array(examples.enumerated()), id: \.offset) { item in
            exampleView(item.element)
        }
    }

    private func exampleView(_ e: Example) -> some View {
        let tiles = e.kinds.enumerated().map { Tile(id: 9_000 + $0.offset, kind: $0.element) }
        let win = scoreWin(tiles, tsumo: e.tsumo)
        let total = win?.total ?? 0
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(total)")
                    .font(AppFont.display(26))
                    .foregroundColor(total >= 30 ? Palette.pinkInk : Palette.ink)
                RubyText(total >= 30 ? "点《てん》 満点《まんてん》！" : "点《てん》", size: 15, bold: true)
                Spacer(minLength: 0)
            }
            RubyText(e.note, size: 13, color: Palette.inkSoft)
            if let win {
                HStack(spacing: 8) {
                    ForEach(Array(win.groups.enumerated()), id: \.offset) { g in
                        HStack(spacing: 2) {
                            ForEach(g.element.tiles) { t in TileView(kind: t.kind, width: 30) }
                        }
                    }
                }
                RubyText(win.items.map { "\($0.label) +\($0.points)" }.joined(separator: "・"), size: 12, color: Palette.inkSoft)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(total >= 30 ? Palette.goldPress : Palette.line, lineWidth: 2))
    }
}

// MARK: - ② コツ

struct LessonTipsPage: View {
    private let tips: [(icon: String, text: String)] = [
        ("square.on.square", "**2枚《まい》ある猫《ねこ》は大事《だいじ》に。**あと1枚《まい》で「同《おな》じ猫《ねこ》」のセットになる。"),
        ("person.3", "**家族《かぞく》は2匹《ひき》そろったら3匹目《ひきめ》を待《ま》つ。**パパ・ママがいたら、子猫《こねこ》が来《く》ればセット。"),
        ("arrow.down.circle", "**バラバラの猫《ねこ》から捨《す》てる。**仲間《なかま》がいない猫《ねこ》は、揃《そろ》うまで時間《じかん》がかかる。"),
        ("sparkles", "**招《まね》き猫《ねこ》は最後《さいご》の1枚《まい》に。**どこにでも入《はい》るけど、使《つか》わずに上《あ》がれば +5点《てん》。"),
        ("number", "**残《のこ》りの枚数《まいすう》を数《かぞ》える。**待《ま》っている猫《ねこ》の横《よこ》の数字《すうじ》は残《のこ》り枚数《まいすう》。多《おお》い方《ほう》が来《き》やすい。"),
        ("eye", "**相手《あいて》の捨《す》てた猫《ねこ》を見《み》る。**ボス猫《ねこ》ランクからは、上《あ》がられると −5点《てん》。相手《あいて》があまり捨《す》てない家族《かぞく》は危《あぶ》ない。"),
        ("pawprint", "**肉球《にくきゅう》マークは「ベストな捨《す》て方《かた》」。**試合《しあい》のあとの「ふりかえり」で、ベストな捨《す》て方《かた》が90%を超《こ》えたら名人《めいじん》。"),
    ]

    var body: some View {
        RubyText("② 強《つよ》くなるコツ", size: 19, display: true)
        HStack(spacing: 3) {
            TileView(kind: kindOf(4, 0), width: 34)
            TileView(kind: kindOf(4, 1), width: 34)
            ghost(kindOf(4, 2))
            Spacer().frame(width: 12)
            TileView(kind: kindOf(2, 2), width: 34)
            TileView(kind: kindOf(2, 2), width: 34)
            ghost(kindOf(2, 2))
        }
        RubyText("どちらも「あと1枚《まい》」の形《かたち》。こういう組《くみ》を2つ3つ作《つく》ると上《あ》がりが近《ちか》い。", size: 12, color: Palette.inkSoft)
        ForEach(Array(tips.enumerated()), id: \.offset) { item in
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: item.element.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Palette.pinkInk)
                    .frame(width: 26)
                RubyText(item.element.text, size: 14)
            }
        }
    }

    private func ghost(_ kind: Int) -> some View {
        CatFace(kind: kind)
            .opacity(0.35)
            .padding(3)
            .frame(width: 34, height: 34 * 1.34)
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Palette.lineStrong, style: StrokeStyle(lineWidth: 2, dash: [4, 3])))
    }
}

// MARK: - ③ ランクアップ

struct LessonRanksPage: View {
    let currentRank: Int
    var onMissions: (() -> Void)?

    var body: some View {
        RubyText("③ ランクアップの道《みち》", size: 19, display: true)
        RubyText("★を集《あつ》めるとランクアップ。強《つよ》い相手《あいて》と戦《たたか》えて、ご褒美《ほうび》のマットももらえる。ランクは下《さ》がらないよ。", size: 14)
        VStack(alignment: .leading, spacing: 6) {
            starRow("CPU対戦《たいせん》で1位《い》", "★2")
            starRow("CPU対戦《たいせん》で2位《い》", "★1")
            starRow("今日《きょう》の1局《きょく》で勝《か》つ", "★1")
            starRow("試合《しあい》のあと動画《どうが》を見《み》る（1日《にち》3回《かい》まで）", "★1")
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.surface2))

        ForEach(Array(Ranks.all.enumerated()), id: \.offset) { item in
            rankRow(item.offset, item.element)
        }
        RubyText("猫神様《ねこがみさま》ランクでは、★6個《こ》ごとに王冠《おうかん》がもらえる。", size: 13, color: Palette.inkSoft)

        if let onMissions {
            Button(action: onMissions) {
                HStack(spacing: 6) {
                    Image(systemName: "rosette")
                    RubyText("目標《もくひょう》を達成《たっせい》して称号《しょうごう》を集《あつ》める", size: 15, display: true, color: Palette.onMint)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PillButtonStyle(kind: .secondary))
        }
    }

    private func starRow(_ text: String, _ stars: String) -> some View {
        HStack {
            RubyText(text, size: 14)
            Spacer(minLength: 0)
            Text(stars)
                .font(AppFont.display(15))
                .foregroundColor(Palette.goldInk)
        }
    }

    private func rankRow(_ i: Int, _ r: RankDef) -> some View {
        let here = i == currentRank
        let cleared = i < currentRank
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return HStack(alignment: .top, spacing: 10) {
            Avatar(kind: r.cpus[0].avatar, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    RubyText(r.name, size: 16, display: true)
                    if here { Chip(text: "今《いま》ここ", fill: Palette.pink, color: Palette.onPink, size: 11) }
                    if cleared { Chip(text: "クリア", size: 11) }
                }
                RubyText(r.blurb, size: 12, color: Palette.inkSoft)
                HStack(spacing: 6) {
                    Circle()
                        .fill(r.mat.style.fill)
                        .overlay(Circle().strokeBorder(r.mat.style.edge, lineWidth: 2))
                        .frame(width: 16, height: 16)
                    RubyText("ご褒美《ほうび》：マット「\(r.mat.name)」・次《つぎ》まで★\(r.starsToNext)", size: 12, bold: true, color: Palette.inkSoft)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(shape.fill(here ? Palette.surface : Palette.surface2))
        .overlay(shape.strokeBorder(here ? Palette.pink : Palette.line, lineWidth: 2))
        .opacity(i > currentRank + 1 ? 0.75 : 1)
    }
}
