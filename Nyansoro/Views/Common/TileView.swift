// 牌・相手の手（裏向き）・丸い猫アイコン

import SwiftUI

struct TileView: View {
    let kind: Int
    let width: CGFloat
    var selected = false
    var recommended = false
    var highlight = false

    private var height: CGFloat { width * 1.34 }
    private var radius: CGFloat { width * 0.18 }
    private var showText: Bool { width >= 46 }
    private var isJokerTile: Bool { kind == joker }
    private var style: FamilyStyle? { isJokerTile ? nil : FamilyColors.all[familyOf(kind)] }

    private var ringColor: Color {
        if selected { return Palette.pink }
        if highlight { return Palette.goldPress }
        if recommended { return Palette.pink }
        return Palette.tileBorder
    }

    private var ringWidth: CGFloat {
        if selected || highlight { return 3 }
        if recommended { return 2 }
        return 1
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                ZStack {
                    Rectangle().fill(isJokerTile ? Palette.jokerBand : style!.band)
                    if showText {
                        Text(isJokerTile ? "招き" : plainText(Catalog.roleNames[roleOf(kind)]))
                            .font(AppFont.body(width * 0.19, bold: true))
                            .foregroundColor(isJokerTile ? Palette.jokerBandInk : style!.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                }
                .frame(height: height * 0.19)

                CatFace(kind: kind)
                    .padding(.horizontal, width * 0.02)
                    .frame(maxHeight: .infinity)

                if showText {
                    Text(isJokerTile ? "万能" : plainText(Catalog.families[familyOf(kind)].name))
                        .font(AppFont.body(width * 0.17, bold: true))
                        .foregroundColor(isJokerTile ? Palette.jokerText : style!.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.bottom, height * 0.05)
                }
            }

            if recommended {
                PawIcon()
                    .frame(width: width * 0.36, height: width * 0.36)
                    .padding(.top, height * 0.2)
                    .padding(.trailing, width * 0.03)
            }
        }
        .frame(width: width, height: height)
        .background(tileFill)
        .clipShape(shape)
        .overlay(shape.strokeBorder(ringColor, lineWidth: ringWidth))
        .background(
            shape.fill(selected ? Palette.pinkPress : Palette.tileEdge)
                .offset(y: width * 0.07)
        )
        .shadow(color: Palette.tileShadow, radius: width * 0.08, x: 0, y: width * 0.1)
        .offset(y: selected ? -height * 0.24 : 0)
        .animation(.easeOut(duration: 0.15), value: selected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(plainText(kindName(kind)) + (recommended ? "（おすすめ）" : ""))
    }

    @ViewBuilder
    private var tileFill: some View {
        if isJokerTile {
            LinearGradient(colors: [Palette.jokerA, Palette.jokerB, Palette.jokerC], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            Palette.tile
        }
    }
}

/// 相手の手持ち（裏向き）
struct TileBacks: View {
    let count: Int

    var body: some View {
        HStack(spacing: -3) {
            ForEach(0..<count, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Palette.back)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Palette.back2).frame(height: 2)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).stroke(Palette.surface, lineWidth: 1))
                    .frame(width: 9, height: 13)
            }
        }
        .padding(.leading, 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("手持ち \(count)枚")
    }
}

/// 丸い猫アイコン（背景はその家族のパステルカラー）
struct Avatar: View {
    let kind: Int
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            Circle().fill(FamilyColors.avatar(kind))
            CatFace(kind: kind)
                .padding(size * 0.04)
                .offset(y: size * 0.06)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Palette.surface, lineWidth: 2))
        .accessibilityHidden(true)
    }
}
