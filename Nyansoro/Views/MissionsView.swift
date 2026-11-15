// 目標と成績：達成すると称号がもらえる。目標の説明そのものが、点数や上がり方のルールを教える。

import SwiftUI

struct MissionsView: View {
    @EnvironmentObject var app: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let progress = app.save.missions
        let stats = app.save.stats
        VStack(spacing: 0) {
            ZStack {
                RubyText("目標《もくひょう》と成績《せいせき》", size: 22, display: true)
                HStack {
                    Spacer()
                    IconButton(icon: .close, label: "閉じる") { dismiss() }
                }
            }
            .padding(16)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    statsGrid(stats)
                    HStack(spacing: 6) {
                        Image(systemName: "rosette").foregroundColor(Palette.goldInk)
                        RubyText("称号《しょうごう》 \(progress.done.count)/\(Missions.all.count)", size: 15, bold: true)
                        if let badge = progress.latestBadge {
                            Chip(text: badge, fill: Palette.gold.opacity(0.45), size: 12)
                        }
                    }
                    ForEach([1, 2, 3], id: \.self) { tier in
                        RubyText(tier == 1 ? "かんたん" : tier == 2 ? "ふつう" : "むずかしい", size: 15, display: true, color: Palette.inkSoft)
                            .padding(.top, 4)
                        ForEach(Missions.all.filter { $0.tier == tier }) { m in
                            row(m, progress)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .frame(maxWidth: 640, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Palette.bg.ignoresSafeArea())
    }

    private func statsGrid(_ s: PlayStats) -> some View {
        let items: [(String, String)] = [
            ("試合数《しあいすう》", "\(s.matches)"),
            ("上《あ》がった回数《かいすう》", "\(s.wins)"),
            ("上《あ》がり率《りつ》", s.rounds == 0 ? "-" : "\(Int((s.winRate * 100).rounded()))%"),
            ("最高点《さいこうてん》", s.bestPoints == 0 ? "-" : "\(s.bestPoints)"),
            ("最速《さいそく》の上《あ》がり", s.fastestWin == 0 ? "-" : "\(s.fastestWin)巡目《じゅんめ》"),
            ("ベストな捨《す》て方《かた》", s.decisions == 0 ? "-" : "\(Int((s.accuracy * 100).rounded()))%"),
        ]
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { item in
                VStack(spacing: 2) {
                    RubyText(item.element.1, size: 18, display: true)
                    RubyText(item.element.0, size: 11, bold: true, color: Palette.inkSoft, alignment: .center)
                }
                .frame(maxWidth: .infinity, minHeight: 64)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.line, lineWidth: 2))
            }
        }
    }

    private func row(_ m: MissionDef, _ p: MissionProgress) -> some View {
        let done = p.isDone(m.id)
        let count = min(p.count(m.id), m.target)
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: done ? "rosette" : "circle.dashed")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(done ? Palette.goldInk : Palette.lineStrong)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                RubyText(m.title, size: 15, bold: true)
                RubyText(m.detail, size: 12, color: Palette.inkSoft)
                if m.target > 1 && !done {
                    HStack(spacing: 8) {
                        MeterBar(value: Double(count) / Double(m.target), color: Palette.pinkPress)
                        Text("\(count)/\(m.target)")
                            .font(AppFont.body(12, bold: true))
                            .foregroundColor(Palette.inkSoft)
                            .monospacedDigit()
                    }
                }
                RubyText(done ? "称号《しょうごう》「\(m.badge)」ゲット！" : "称号《しょうごう》：？？？", size: 12, bold: true, color: done ? Palette.goldInk : Palette.inkSoft)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(shape.fill(done ? Palette.surface : Palette.surface2))
        .overlay(shape.strokeBorder(done ? Palette.goldPress : Palette.line, lineWidth: 2))
    }
}
