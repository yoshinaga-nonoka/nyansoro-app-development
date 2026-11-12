// ふりがな付きの文字。「猫《ねこ》を捨《す》てる」のように書くと、漢字の上に読みが出る。
// 「**ここ**」で太字。設定でふりがなを消すと、読みの行ごとなくなる。

import SwiftUI

private struct FuriganaKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var furigana: Bool {
        get { self[FuriganaKey.self] }
        set { self[FuriganaKey.self] = newValue }
    }
}

struct RubyToken {
    var base: String
    var reading: String?
    var bold: Bool

    private static let closing: Set<Character> = ["、", "。", "，", "．", "！", "？", "」", "』", "）", "…", "ー", "〜", "：", "!", "?", ")", "・"]
    private static let opening: Set<Character> = ["「", "『", "（", "("]

    /// 文字ごとに区切る（行の頭に「。」などが来ないように前の文字とくっつける）
    static func tokens(from text: String) -> [RubyToken] {
        var out: [RubyToken] = []
        var bold = false
        var pendingOpen = ""
        for part in parseRuby(text) {
            switch part {
            case let .ruby(base, reading):
                if !pendingOpen.isEmpty {
                    out.append(RubyToken(base: pendingOpen, reading: nil, bold: bold))
                    pendingOpen = ""
                }
                out.append(RubyToken(base: base, reading: reading, bold: bold))
            case let .text(s):
                let chars = Array(s)
                var i = 0
                while i < chars.count {
                    let ch = chars[i]
                    if ch == "*", i + 1 < chars.count, chars[i + 1] == "*" {
                        bold.toggle()
                        i += 2
                        continue
                    }
                    if opening.contains(ch) {
                        pendingOpen.append(ch)
                    } else if closing.contains(ch), let last = out.last, last.reading == nil, pendingOpen.isEmpty {
                        out[out.count - 1].base.append(ch)
                    } else {
                        out.append(RubyToken(base: pendingOpen + String(ch), reading: nil, bold: bold))
                        pendingOpen = ""
                    }
                    i += 1
                }
            }
        }
        if !pendingOpen.isEmpty { out.append(RubyToken(base: pendingOpen, reading: nil, bold: bold)) }
        return out
    }
}

struct RubyText: View {
    let text: String
    var size: CGFloat = 15
    var bold = false
    var display = false
    var color: Color = Palette.ink
    var alignment: HorizontalAlignment = .leading
    @Environment(\.furigana) private var furigana

    init(_ text: String, size: CGFloat = 15, bold: Bool = false, display: Bool = false, color: Color = Palette.ink, alignment: HorizontalAlignment = .leading) {
        self.text = text
        self.size = size
        self.bold = bold
        self.display = display
        self.color = color
        self.alignment = alignment
    }

    var body: some View {
        let tokens = RubyToken.tokens(from: text)
        FlowLayout(alignment: alignment) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { item in
                tokenView(item.element)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(plainText(text).replacingOccurrences(of: "**", with: ""))
    }

    private func font(_ s: CGFloat, strong: Bool) -> Font {
        display ? AppFont.display(s) : AppFont.body(s, bold: strong)
    }

    /// 読みが漢字より長いとき、左右に足す余白（読みは両隣に 1/4 文字ずつ はみ出してよい）
    private func sidePadding(_ t: RubyToken) -> CGFloat {
        guard furigana, let reading = t.reading else { return 0 }
        let readingWidth = CGFloat(reading.count) * size * 0.5
        let baseWidth = CGFloat(t.base.count) * size
        return max(0, (readingWidth - baseWidth - size * 0.5) / 2)
    }

    private func tokenView(_ t: RubyToken) -> some View {
        VStack(spacing: 0) {
            if furigana {
                // 読みの行の高さだけ空けておき、読みは上に重ねる
                Text(" ")
                    .font(AppFont.body(size * 0.5, bold: true))
                    .hidden()
            }
            Text(t.base)
                .font(font(size, strong: bold || t.bold))
                .foregroundColor(color)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, sidePadding(t))
        .overlay(alignment: .top) {
            if furigana, let reading = t.reading {
                Text(reading)
                    .font(AppFont.body(size * 0.5, bold: true))
                    .foregroundColor(color.opacity(0.9))
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }
}

/// 子ビューを左から並べ、幅が足りなくなったら折り返す
struct FlowLayout: Layout {
    var alignment: HorizontalAlignment = .leading
    var lineSpacing: CGFloat = 1

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = makeRows(maxWidth: maxWidth, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.reduce(CGFloat(0)) { $0 + $1.height } + lineSpacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: min(width, maxWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = makeRows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            if alignment == .center {
                x += (bounds.width - row.width) / 2
            } else if alignment == .trailing {
                x += bounds.width - row.width
            }
            for i in row.indices {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y + row.height - size.height), anchor: .topLeading, proposal: ProposedViewSize(size))
                x += size.width
            }
            y += row.height + lineSpacing
        }
    }

    private func makeRows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for i in subviews.indices {
            let size = subviews[i].sizeThatFits(.unspecified)
            if !current.indices.isEmpty, current.width + size.width > maxWidth + 0.5 {
                rows.append(current)
                current = Row()
            }
            current.indices.append(i)
            current.width += size.width
            current.height = max(current.height, size.height)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
