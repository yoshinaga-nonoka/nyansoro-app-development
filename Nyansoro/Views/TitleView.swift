// タイトル画面

import SwiftUI

struct TitleView: View {
    @ObservedObject var app: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Spacer()
                IconButton(icon: .settings, label: "設定") { app.showSettings = true }
                HelpButton { app.showHelp = true }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            GeometryReader { geo in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 22) {
                        hero(width: min(geo.size.width, 560))
                        dailyCard
                        rankCard
                        menu
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity, minHeight: geo.size.height)
                }
            }
        }
        .background(Palette.bg.ignoresSafeArea())
    }

    private func hero(width: CGFloat) -> some View {
        VStack(spacing: 10) {
            HeroTiles()
            LogoView(size: min(66, (width - 40) / 5.4))
            RubyText("猫《ねこ》を3枚《まい》ずつ揃《そろ》えよう！", size: 15, bold: true, color: Palette.inkSoft)
                .fixedSize()
                .padding(.horizontal, 16)
                .padding(.vertical, 5)
                .background(Capsule().fill(Palette.surface))
                .overlay(Capsule().strokeBorder(Palette.line, lineWidth: 2))
        }
    }

    /// 今日の1局と連続日数
    private var dailyCard: some View {
        let status = app.streakStatus
        let done = status == .doneToday
        let result = app.todaysDaily
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        let note: String
        if let r = result {
            note = r.won ? "クリア！ \(r.turns)巡目《じゅんめ》で上《あ》がり。また明日《あした》ね" : "挑戦《ちょうせん》済《ず》み。また明日《あした》ね"
        } else if status == .revivable {
            note = "昨日《きのう》お休《やす》みしたよ。動画《どうが》を見《み》ると連続記録《れんぞくきろく》を守《まも》れる"
        } else {
            note = "全員《ぜんいん》同《おな》じ配牌《はいぱい》の1局《きょく》勝負《しょうぶ》。勝《か》つと★+1"
        }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Palette.pinkInk)
                RubyText("今日《きょう》の1局《きょく》", size: 19, display: true)
                Spacer(minLength: 0)
                StreakBadge(count: app.streakCount)
            }
            RubyText(note, size: 13, color: Palette.inkSoft)
            if app.canReviveStreak {
                Button {
                    Task { await app.reviveStreak() }
                } label: {
                    RubyText("動画《どうが》を見《み》て連続記録《れんぞくきろく》を守《まも》る", size: 15, display: true, color: Palette.onMint)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PillButtonStyle(kind: .secondary))
            }
            if !done {
                Button { app.play(.daily(day: app.today)) } label: {
                    RubyText("挑戦《ちょうせん》する", size: 17, display: true, color: Palette.onGold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PillButtonStyle(kind: .nyan))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(shape.fill(Palette.surface))
        .overlay(shape.strokeBorder(done ? Palette.line : Palette.goldPress, lineWidth: 2))
        .shadow(color: Palette.shadow, radius: 14, x: 0, y: 8)
    }

    private var rankCard: some View {
        let rank = app.currentRank
        let progress = app.save.progress
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        return HStack(spacing: 16) {
            Avatar(kind: rank.cpus[0].avatar, size: 66)
            VStack(alignment: .leading, spacing: 3) {
                RubyText("今《いま》のランク", size: 12, bold: true, color: Palette.inkSoft)
                HStack(alignment: .bottom, spacing: 6) {
                    RubyText(rank.name, size: 22, display: true)
                    if progress.crowns > 0 {
                        RubyText("王冠《おうかん》×\(progress.crowns)", size: 13, bold: true, color: Palette.goldInk)
                    }
                }
                HStack(spacing: 2) {
                    ForEach(0..<rank.starsToNext, id: \.self) { i in
                        Text("★")
                            .font(.system(size: 20))
                            .foregroundColor(i < progress.stars ? Palette.goldPress : Palette.lineStrong)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("★ \(progress.stars) / \(rank.starsToNext)")
                RubyText("あと★\(rank.starsToNext - progress.stars)個《こ》で\(progress.rank == Ranks.all.count - 1 ? "王冠《おうかん》" : "ランクアップ")", size: 12, bold: true, color: Palette.inkSoft)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(shape.fill(Palette.surface))
        .overlay(shape.strokeBorder(Palette.line, lineWidth: 2))
        .shadow(color: Palette.shadow, radius: 14, x: 0, y: 8)
    }

    private var menu: some View {
        VStack(spacing: 12) {
            if !app.save.progress.tutorialDone {
                RubyText("初《はじ》めての人《ひと》は「練習《れんしゅう》」から！", size: 14, bold: true, color: Palette.pinkInk)
            }
            Button { app.play(.cpu(rank: app.save.progress.rank)) } label: {
                VStack(spacing: 0) {
                    RubyText("CPUと対戦《たいせん》", size: 24, display: true, color: Palette.onPink)
                    RubyText("\(app.currentRank.name)ランク", size: 12, bold: true, color: Palette.onPink)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PillButtonStyle(kind: .primary, big: true))

            HStack(spacing: 12) {
                Button { app.play(.tutorial) } label: {
                    RubyText("練習《れんしゅう》", size: 16, display: true, color: app.save.progress.tutorialDone ? Palette.ink : Palette.onMint)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PillButtonStyle(kind: app.save.progress.tutorialDone ? .ghost : .secondary))
                Button { app.showRanks() } label: {
                    RubyText("ランクを選《えら》ぶ", size: 16, display: true)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PillButtonStyle(kind: .ghost))
            }

            HStack(spacing: 12) {
                soonButton("友達《ともだち》とオンライン")
                soonButton("誰《だれ》かとオンライン")
            }
        }
    }

    private func soonButton(_ title: String) -> some View {
        Button { app.showOnline = true } label: {
            VStack(spacing: 2) {
                RubyText(title, size: 14, display: true, color: Palette.inkSoft)
                RubyText("準備中《じゅんびちゅう》", size: 11, bold: true, color: Palette.pinkInk)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PillButtonStyle(kind: .soon))
    }
}

/// タイトルの上で揺れる4枚の牌
struct HeroTiles: View {
    @State private var bob = false
    private let kinds = [kindOf(1, 0), kindOf(1, 1), kindOf(1, 2), joker]
    private let angles: [Double] = [-9, -3, 3, 10]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<kinds.count, id: \.self) { i in
                TileView(kind: kinds[i], width: 52)
                    .rotationEffect(.degrees(angles[i]))
                    .offset(y: bob ? (i % 2 == 0 ? -5 : 3) : (i % 2 == 0 ? 3 : -5))
                    .padding(.leading, i == 3 ? 12 : 0)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { bob = true }
        }
        .accessibilityHidden(true)
    }
}

/// 「にゃんそろ」のロゴ（パステルの文字を濃い色で縁取り）
struct LogoView: View {
    let size: CGFloat
    private let letters = Array("にゃんそろ").map(String.init)
    private static let outline = Color(hex: 0x4A3F5C)
    private static let offsets: [CGSize] = [
        CGSize(width: 2.5, height: 0), CGSize(width: -2.5, height: 0), CGSize(width: 0, height: 2.5), CGSize(width: 0, height: -2.5),
        CGSize(width: 1.8, height: 1.8), CGSize(width: -1.8, height: 1.8), CGSize(width: 1.8, height: -1.8), CGSize(width: -1.8, height: -1.8),
    ]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<letters.count, id: \.self) { i in
                letter(letters[i], fill: FamilyColors.all[i].band)
                    .rotationEffect(.degrees(i % 2 == 0 ? -5 : 4))
                    .offset(y: i % 2 == 0 ? 0 : 5)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("にゃんそろ")
        .accessibilityAddTraits(.isHeader)
    }

    private func letter(_ ch: String, fill: Color) -> some View {
        ZStack {
            Text(ch).font(AppFont.display(size)).foregroundColor(Self.outline).offset(y: 7)
            ForEach(0..<Self.offsets.count, id: \.self) { i in
                Text(ch).font(AppFont.display(size)).foregroundColor(Self.outline).offset(Self.offsets[i])
            }
            Text(ch).font(AppFont.display(size)).foregroundColor(fill)
        }
    }
}
