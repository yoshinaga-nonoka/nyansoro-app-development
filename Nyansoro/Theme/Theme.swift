// 配色とフォント。テーマは「猫カフェのドリンク」：ラムネ・苺ミルク・抹茶ミルク・蜂蜜。
// 色はすべてライト／ダークの組で定義する（端末の設定に自動で合わせる）。

import SwiftUI
import UIKit
import CoreText

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(uiColor: UIColor(hex: hex, alpha: CGFloat(alpha)))
    }

    /// ライト／ダークで色を切り替える
    static func dynamic(_ light: UInt32, _ dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark, alpha: darkAlpha) : UIColor(hex: light, alpha: lightAlpha)
        })
    }
}

enum Palette {
    static let bg = Color.dynamic(0xF8F4FB, 0x1D1A29)
    static let surface = Color.dynamic(0xFFFFFF, 0x2A2639)
    static let surface2 = Color.dynamic(0xFAF6FD, 0x232033)
    static let ink = Color.dynamic(0x4A3F5C, 0xF2EDFA)
    static let inkSoft = Color.dynamic(0x776D8D, 0xBAB1CE)
    static let line = Color.dynamic(0xECE4F3, 0x3A3450)
    static let lineStrong = Color.dynamic(0xD9CDE7, 0x4B4465)
    static let shadow = Color.dynamic(0x6E5A8C, 0x000000, lightAlpha: 0.16, darkAlpha: 0.35)

    static let pink = Color.dynamic(0xFFB7D0, 0xF5ABC8)
    static let pinkPress = Color.dynamic(0xF397B9, 0xD684A6)
    static let onPink = Color.dynamic(0x5E1F3F, 0x4A1531)
    static let pinkInk = Color.dynamic(0xC2447A, 0xFF9FC6)
    static let gold = Color.dynamic(0xFFE08E, 0xF5D784)
    static let goldPress = Color.dynamic(0xEFC25A, 0xD2AE55)
    static let onGold = Color.dynamic(0x5A4100, 0x3F2E00)
    static let goldInk = Color.dynamic(0xA07000, 0xF5D784)
    static let mint = Color.dynamic(0xC4ECD7, 0xA8DBC1)
    static let mintPress = Color.dynamic(0x8FD2B0, 0x79BD9B)
    static let onMint = Color.dynamic(0x1C5F40, 0x143D2A)
    static let lavender = Color.dynamic(0xE6DCF8, 0x4A4168)
    static let ok = Color.dynamic(0x45BB84, 0x6FD3A2)
    static let bad = Color.dynamic(0xE06464, 0xFF8585)
    static let overlay = Color.dynamic(0x4A3F5C, 0x0A0812, lightAlpha: 0.32, darkAlpha: 0.6)

    // 牌は どちらのテーマでも「白い陶器のもの」として描く
    static let tile = Color.dynamic(0xFFFEFA, 0xFBF7EF)
    static let tileInk = Color(hex: 0x4A3F5C)
    static let tileBorder = Color.dynamic(0xE6DFF0, 0xD8CFE6)
    static let tileEdge = Color.dynamic(0xD8CDEC, 0x7F71A0)
    static let tileShadow = Color.dynamic(0x6E5A8C, 0x000000, lightAlpha: 0.22, darkAlpha: 0.45)
    static let jokerA = Color(hex: 0xFFF8DC)
    static let jokerB = Color(hex: 0xFFE39A)
    static let jokerC = Color(hex: 0xFFD46E)
    static let jokerBand = Color(hex: 0xFFC4CB)
    static let jokerBandInk = Color(hex: 0x8A2634)
    static let jokerText = Color(hex: 0x8C6200)
    static let back = Color.dynamic(0xE2D7F7, 0x9384BD)
    static let back2 = Color.dynamic(0xCBBAF0, 0x73659F)

    // マット（座布団）の上
    static let matInk = Color.dynamic(0x4A3F5C, 0xF2EDFA)
    static let matInkSoft = Color.dynamic(0x6C6283, 0xCFC6E2)
    static let matPanel = Color.dynamic(0xFFFFFF, 0xFFFFFF, lightAlpha: 0.6, darkAlpha: 0.07)
    static let matPanelStrong = Color.dynamic(0xFFFFFF, 0xFFFFFF, lightAlpha: 0.92, darkAlpha: 0.15)
    static let matStitch = Color.dynamic(0xFFFFFF, 0xFFFFFF, lightAlpha: 0.85, darkAlpha: 0.18)
}

struct FamilyStyle {
    let band: Color
    let ink: Color
    let text: Color
}

enum FamilyColors {
    // 三毛・黒・白・茶トラ・サバトラ・ハチワレ
    static let all: [FamilyStyle] = [
        FamilyStyle(band: Color(hex: 0xFFC4CB), ink: Color(hex: 0x8A2634), text: Color(hex: 0xC03A4B)),
        FamilyStyle(band: Color(hex: 0xDCCBF6), ink: Color(hex: 0x4C2A7D), text: Color(hex: 0x7448B0)),
        FamilyStyle(band: Color(hex: 0xC2E3FB), ink: Color(hex: 0x1B5480), text: Color(hex: 0x2A74AB)),
        FamilyStyle(band: Color(hex: 0xFFD7B3), ink: Color(hex: 0x86430A), text: Color(hex: 0xB0580F)),
        FamilyStyle(band: Color(hex: 0xC4ECD7), ink: Color(hex: 0x1C5F40), text: Color(hex: 0x24794F)),
        FamilyStyle(band: Color(hex: 0xFDE9A6), ink: Color(hex: 0x634B00), text: Color(hex: 0x8C6800)),
    ]

    static func avatar(_ kind: Int) -> Color {
        kind == joker ? Palette.jokerB : all[familyOf(kind)].band
    }
}

struct MatStyle {
    let fill: Color
    let edge: Color
}

extension MatId {
    var style: MatStyle {
        switch self {
        case .ramune: return MatStyle(fill: .dynamic(0xD2E8F8, 0x2B3D52), edge: .dynamic(0xB7D6EF, 0x23344A))
        case .ichigo: return MatStyle(fill: .dynamic(0xFBD8E5, 0x4A3243), edge: .dynamic(0xF1BDD1, 0x3E2939))
        case .matcha: return MatStyle(fill: .dynamic(0xD6EEDB, 0x2C4536), edge: .dynamic(0xB9DEC1, 0x243A2D))
        case .yozora: return MatStyle(fill: .dynamic(0xDCD5F4, 0x312B50), edge: .dynamic(0xC4B9EB, 0x28234A))
        case .hachimitsu: return MatStyle(fill: .dynamic(0xFCEBBD, 0x4A3F26), edge: .dynamic(0xF1D58E, 0x3E341F))
        }
    }
}

/// 同梱フォント（どちらも SIL Open Font License）。読み込めなければ端末のフォントになる
enum AppFont {
    static let displayName = "MochiyPopOne-Regular"
    static let bodyName = "ZenMaruGothic-Medium"
    static let boldName = "ZenMaruGothic-Bold"

    static func register() {
        for name in [displayName, bodyName, boldName] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            _ = CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    static func display(_ size: CGFloat) -> Font { .custom(displayName, fixedSize: size) }
    static func body(_ size: CGFloat, bold: Bool = false) -> Font { .custom(bold ? boldName : bodyName, fixedSize: size) }
}
