// 共通の部品：丸いボタン、モーダルのカード、点線、小さなラベル

import SwiftUI

struct PillButtonStyle: ButtonStyle {
    enum Kind {
        case primary, secondary, ghost, nyan, small, danger, soon
    }

    var kind: Kind
    var big = false

    private var fill: Color {
        switch kind {
        case .primary, .small: return Palette.pink
        case .secondary: return Palette.mint
        case .ghost, .soon: return Palette.surface
        case .nyan: return Palette.gold
        case .danger: return Palette.bad
        }
    }

    private var press: Color {
        switch kind {
        case .primary, .small, .danger: return Palette.pinkPress
        case .secondary: return Palette.mintPress
        case .ghost: return Palette.lineStrong
        case .nyan: return Palette.goldPress
        case .soon: return .clear
        }
    }

    private var foreground: Color {
        switch kind {
        case .primary, .small: return Palette.onPink
        case .secondary: return Palette.onMint
        case .ghost: return Palette.ink
        case .soon: return Palette.inkSoft
        case .nyan: return Palette.onGold
        case .danger: return Palette.surface
        }
    }

    private var fontSize: CGFloat {
        if big { return 22 }
        switch kind {
        case .small: return 14
        case .nyan: return 22
        default: return 16
        }
    }

    private var minHeight: CGFloat {
        if big { return 72 }
        return kind == .small ? 34 : 48
    }

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let depth: CGFloat = kind == .soon ? 0 : (kind == .nyan ? 5 : 4)
        configuration.label
            .font(AppFont.display(fontSize))
            .foregroundColor(foreground)
            .multilineTextAlignment(.center)
            .padding(.horizontal, kind == .small ? 14 : 22)
            .padding(.vertical, 6)
            .frame(minHeight: minHeight)
            .background(Capsule().fill(fill))
            .overlay(border)
            .background(Capsule().fill(press).offset(y: pressed ? 1 : depth))
            .offset(y: pressed ? depth - 1 : 0)
            .contentShape(Capsule())
    }

    @ViewBuilder
    private var border: some View {
        switch kind {
        case .ghost:
            Capsule().strokeBorder(Palette.lineStrong, lineWidth: 2)
        case .soon:
            Capsule().strokeBorder(Palette.lineStrong, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
        default:
            EmptyView()
        }
    }
}

/// 画面を暗くして、真ん中にカードを出す
struct ModalCard<Content: View>: View {
    var maxWidth: CGFloat = 520
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            Palette.overlay.ignoresSafeArea()
            ViewThatFits(in: .vertical) {
                card
                ScrollView { card }
            }
            .frame(maxWidth: maxWidth)
            .padding(16)
        }
        .transition(.opacity)
    }

    private var card: some View {
        VStack(spacing: 14) { content() }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Palette.line, lineWidth: 2))
            .shadow(color: Palette.shadow, radius: 24, x: 0, y: 12)
    }
}

/// 横の点線（あと少しのセットの下線）
struct DashLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

/// 丸い小さなラベル
struct Chip: View {
    let text: String
    var fill: Color = Palette.lavender
    var color: Color = Palette.ink
    var size: CGFloat = 13
    var display = false

    var body: some View {
        RubyText(text, size: size, bold: true, display: display, color: color)
            .fixedSize()
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Capsule().fill(fill))
    }
}

/// 四角いアイコンボタン（戻る・設定）
struct IconButton: View {
    enum Icon {
        case back, settings, close
    }

    let icon: Icon
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Palette.ink)
                .frame(width: 42, height: 42)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Palette.lineStrong, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var symbol: String {
        switch icon {
        case .back: return "chevron.left"
        case .settings: return "slider.horizontal.3"
        case .close: return "xmark"
        }
    }
}

/// 黄色い丸の「？」ボタン
struct HelpButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("？")
                .font(AppFont.display(20))
                .foregroundColor(Palette.onGold)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Palette.gold))
                .background(Circle().fill(Palette.goldPress).offset(y: 3))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("遊び方")
    }
}
