// ランクを選ぶ画面

import SwiftUI

struct RankSelectView: View {
    @ObservedObject var app: AppModel

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RubyText("ランクを選《えら》ぶ", size: 20, display: true)
                HStack {
                    IconButton(icon: .back, label: "戻る") { app.showTitle() }
                    Spacer()
                    HelpButton { app.showHelp = true }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 10)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(Ranks.all.enumerated()), id: \.offset) { item in
                        card(item.offset, item.element)
                    }
                }
                .padding(16)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Palette.bg.ignoresSafeArea())
    }

    private func card(_ i: Int, _ r: RankDef) -> some View {
        let current = app.save.progress.rank
        let locked = i > current
        let isCurrent = i == current
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Circle()
                    .fill(r.mat.style.fill)
                    .overlay(Circle().strokeBorder(r.mat.style.edge, lineWidth: 2))
                    .frame(width: 22, height: 22)
                RubyText(r.name, size: 19, display: true)
                Spacer(minLength: 0)
                Chip(
                    text: locked ? "まだ遊《あそ》べない" : isCurrent ? "★を集《あつ》めよう" : "クリア",
                    fill: isCurrent ? Palette.pink : Palette.lavender,
                    color: isCurrent ? Palette.onPink : Palette.ink,
                    size: 12
                )
            }
            HStack(spacing: 12) {
                ForEach(Array(r.cpus.enumerated()), id: \.offset) { item in
                    HStack(spacing: 6) {
                        Avatar(kind: item.element.avatar, size: 26)
                        RubyText(item.element.name, size: 13, bold: true)
                    }
                }
            }
            RubyText(r.blurb, size: 13, color: Palette.inkSoft)
            ForEach(r.rules, id: \.self) { rule in
                RubyText("・\(rule)", size: 13, bold: true, color: Palette.pinkInk)
            }
            Button { app.play(.cpu(rank: i)) } label: {
                RubyText(
                    locked ? "\(Ranks.all[max(0, i - 1)].name)ランクで★\(Ranks.all[max(0, i - 1)].starsToNext)個《こ》" : isCurrent ? "遊《あそ》ぶ" : "遊《あそ》ぶ（★なし）",
                    size: 15,
                    display: true,
                    color: isCurrent ? Palette.onPink : Palette.ink
                )
            }
            .buttonStyle(PillButtonStyle(kind: isCurrent ? .primary : .ghost))
            .disabled(locked)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(Palette.surface))
        .overlay(shape.strokeBorder(isCurrent ? Palette.pink : Palette.line, lineWidth: 2))
        .opacity(locked ? 0.6 : 1)
    }
}
