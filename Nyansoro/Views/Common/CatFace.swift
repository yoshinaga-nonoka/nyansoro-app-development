// 猫の絵柄（絵本風）。100×100 の座標の SVG path を Path にして Canvas で描く。
// 家族は毛の模様で、パパ・ママ・子猫は「蝶ネクタイ・リボン・鈴＋小さい顔」で見分ける。

import SwiftUI

/// SVG の path 文字列（M / L / C / Q / Z の絶対座標だけ）を Path にする
enum SVGPath {
    static func parse(_ d: String) -> Path {
        var tokens: [String] = []
        var number = ""
        func flushNumber() {
            if !number.isEmpty {
                tokens.append(number)
                number = ""
            }
        }
        for ch in d {
            if ch.isLetter {
                flushNumber()
                tokens.append(String(ch))
            } else if ch == " " || ch == "," {
                flushNumber()
            } else if ch == "-" {
                flushNumber()
                number = "-"
            } else {
                number.append(ch)
            }
        }
        flushNumber()

        var path = Path()
        var i = 0
        var command = "M"
        func value() -> CGFloat {
            let v = i < tokens.count ? Double(tokens[i]) ?? 0 : 0
            i += 1
            return CGFloat(v)
        }
        func point() -> CGPoint {
            let x = value()
            let y = value()
            return CGPoint(x: x, y: y)
        }
        while i < tokens.count {
            if let first = tokens[i].first, first.isLetter {
                command = tokens[i]
                i += 1
                if command == "Z" || command == "z" {
                    path.closeSubpath()
                    continue
                }
            }
            switch command {
            case "M":
                path.move(to: point())
                command = "L"
            case "L":
                path.addLine(to: point())
            case "C":
                let c1 = point()
                let c2 = point()
                let p = point()
                path.addCurve(to: p, control1: c1, control2: c2)
            case "Q":
                let c = point()
                let p = point()
                path.addQuadCurve(to: p, control: c)
            default:
                i += 1
            }
        }
        return path
    }
}

private enum Shapes {
    static let outline = Color(hex: 0x5B4339)
    static let head = SVGPath.parse("M12 61 C11 50 14 41 19 34 C18 26 18 18 21 12 C22.5 9.5 25 9 27.5 10.5 C32.5 13.5 37.5 18.5 41 23 C47 21.3 53 21.3 59 23 C62.5 18.5 67.5 13.5 72.5 10.5 C75 9 77.5 9.5 79 12 C82 18 82 26 81 34 C86 41 89 50 88 61 C87 78 71 89 50 89 C29 89 13 78 12 61 Z")
    static let earL = SVGPath.parse("M24.5 15.5 C28.5 18.5 32.5 22.5 35.5 26.5 C30.5 27.5 26.5 29.5 23 32.5 C22 26.5 22.5 20.5 24.5 15.5 Z")
    static let earR = SVGPath.parse("M75.5 15.5 C71.5 18.5 67.5 22.5 64.5 26.5 C69.5 27.5 73.5 29.5 77 32.5 C78 26.5 77.5 20.5 75.5 15.5 Z")
    static let mikeOrange = SVGPath.parse("M8 8 L44 8 C47 18 46 30 40 37 C33 45 22 47 8 52 Z")
    static let mikeBlack = SVGPath.parse("M57 20 C62 12 75 4 92 8 L92 46 C84 45 74 41 68 35 C62 30 58 25 57 20 Z")
    static let hachiWhite = SVGPath.parse("M50 33 C46 43 40 50 33 56 C26 62 24 74 30 92 L70 92 C76 74 74 62 67 56 C60 50 54 43 50 33 Z")
    static let stripesHead = SVGPath.parse("M43 25.5 C43.5 29 44.3 32 45.5 34.5 M50 24 L50 34 M57 25.5 C56.5 29 55.7 32 54.5 34.5")
    static let stripesCheek = SVGPath.parse("M11 55 C15 55 19 56 22 57.5 M11.5 63 C15 62.5 19 62.5 22 63.5 M89 55 C85 55 81 56 78 57.5 M88.5 63 C85 62.5 81 62.5 78 63.5")
    static let muzzle = SVGPath.parse("M36 70 C36 63 43 61 50 64 C57 61 64 63 64 70 C64 76 57 79 50 77 C43 79 36 76 36 70 Z")
    static let nose = SVGPath.parse("M46.6 65.2 C46.6 63.8 53.4 63.8 53.4 65.2 C53.4 66.8 51.3 68.4 50 68.4 C48.7 68.4 46.6 66.8 46.6 65.2 Z")
    static let mouth = SVGPath.parse("M50 68.4 L50 70 M44.5 69.8 C45.5 72.8 49 72.8 50 70 C51 72.8 54.5 72.8 55.5 69.8")
    static let whiskers = SVGPath.parse("M4 62 C10 61.5 15 62 20 63.5 M5 69 C10 68 15 67.8 20.5 68.2 M96 62 C90 61.5 85 62 80 63.5 M95 69 C90 68 85 67.8 79.5 68.2")
    static let happyEyes = SVGPath.parse("M30.5 59 C32.5 54.5 39.5 54.5 41.5 59 M58.5 59 C60.5 54.5 67.5 54.5 69.5 59")
    static let lashes = SVGPath.parse("M32 54.4 C30.4 53.8 29.2 52.8 28.4 51.4 M70 54.4 C71.6 53.8 72.8 52.8 73.6 51.4")
    static let bowL = SVGPath.parse("M50 91.5 C45 86 37 83 35.5 86.5 C34.5 89.5 34.5 93.5 35.5 96.5 C37 100 45 97 50 91.5 Z")
    static let bowR = SVGPath.parse("M50 91.5 C55 86 63 83 64.5 86.5 C65.5 89.5 65.5 93.5 64.5 96.5 C63 100 55 97 50 91.5 Z")
    static let bowFolds = SVGPath.parse("M38.5 88.5 C40.5 90 40.5 93 38.5 94.5 M61.5 88.5 C59.5 90 59.5 93 61.5 94.5")
    static let ribbonL = SVGPath.parse("M70 22 C64 12 55 15 57.5 22.5 C59.5 28 65.5 26.5 70 22 Z")
    static let ribbonR = SVGPath.parse("M70 22 C73 11 82.5 11 82.5 18.5 C82.5 25 74.5 26 70 22 Z")
    static let ribbonTails = SVGPath.parse("M68.5 24 C67 28 65.5 30.5 63.5 32 M71.5 24 C73.5 27.5 75.5 29.5 78 30.5")
    static let kittenCollar = SVGPath.parse("M30 81.5 C40 87.5 60 87.5 70 81.5")
    static let manekiCollar = SVGPath.parse("M28 82.5 C40 89.5 60 89.5 72 82.5")
    static let manekiPaw = SVGPath.parse("M3 52 C1 44 2 35 8 31 C13 28 19 31 20 37 C21 43 20 49 17 54 Z")
}

private struct Fur {
    let base: Color
    let earIn: Color
    let whisker: Color
    let dark: Bool
    let pattern: Int // 0なし 1三毛 2しま 3ハチワレ
    let stripe: Color
}

private let furs: [Fur] = [
    Fur(base: Color(hex: 0xFFF8EC), earIn: Color(hex: 0xF8B4C2), whisker: Color(hex: 0x9C8578), dark: false, pattern: 1, stripe: .clear),
    Fur(base: Color(hex: 0x3A3138), earIn: Color(hex: 0x8C6474), whisker: Color(hex: 0xD9CCD4), dark: true, pattern: 0, stripe: .clear),
    Fur(base: Color(hex: 0xFFFFFF), earIn: Color(hex: 0xF8B4C2), whisker: Color(hex: 0xA8988F), dark: false, pattern: 0, stripe: .clear),
    Fur(base: Color(hex: 0xF6B26B), earIn: Color(hex: 0xF9BFC0), whisker: Color(hex: 0x9A6A43), dark: false, pattern: 2, stripe: Color(hex: 0xDE8640)),
    Fur(base: Color(hex: 0xB9BDC6), earIn: Color(hex: 0xF2BCC8), whisker: Color(hex: 0x626774), dark: false, pattern: 2, stripe: Color(hex: 0x7A808D)),
    Fur(base: Color(hex: 0x3A3138), earIn: Color(hex: 0x8C6474), whisker: Color(hex: 0xD9CCD4), dark: true, pattern: 3, stripe: .clear),
]

private let accessoryColors: [Color] = [
    Color(hex: 0xF28C9A), Color(hex: 0xB08BE6), Color(hex: 0x6DB6EC), Color(hex: 0xF4A65A), Color(hex: 0x5CC594), Color(hex: 0xEDC04A),
]

enum CatPainter {
    private static func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
    }

    private static func stroke(_ ctx: inout GraphicsContext, _ path: Path, _ color: Color, _ width: CGFloat) {
        ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    private static func fillOutlined(_ ctx: inout GraphicsContext, _ path: Path, _ color: Color, _ width: CGFloat = 1.6) {
        ctx.fill(path, with: .color(color))
        ctx.stroke(path, with: .color(Shapes.outline), style: StrokeStyle(lineWidth: width, lineJoin: .round))
    }

    /// ふんわりしたほっぺ（中心から外へ透明になる）
    private static func blush(_ ctx: inout GraphicsContext, _ cx: CGFloat, _ cy: CGFloat, strength: Double) {
        var c = ctx
        c.translateBy(x: cx, y: cy)
        c.scaleBy(x: 1, y: 5.0 / 8.0)
        let pink = Color(hex: 0xFF8FA8)
        c.fill(ellipse(0, 0, 8, 8), with: .radialGradient(
            Gradient(colors: [pink.opacity(strength), pink.opacity(0)]),
            center: .zero, startRadius: 0, endRadius: 8))
    }

    /// 鈴
    private static func bell(_ ctx: inout GraphicsContext, _ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) {
        let body = ellipse(cx, cy, r, r)
        ctx.fill(body, with: .color(Color(hex: 0xF7CB4D)))
        ctx.stroke(body, with: .color(Color(hex: 0xA87A12)), lineWidth: 1.2)
        ctx.fill(ellipse(cx - r * 0.35, cy - r * 0.35, r * 0.32, r * 0.32), with: .color(Color(hex: 0xFFF3C4)))
        var slit = Path()
        slit.move(to: CGPoint(x: cx, y: cy + r * 0.15))
        slit.addLine(to: CGPoint(x: cx, y: cy + r * 0.75))
        stroke(&ctx, slit, Color(hex: 0xA87A12), 1.1)
    }

    private static func face(_ ctx: inout GraphicsContext, fur: Fur, bigEyes: Bool = false, happy: Bool = false, lashes: Bool = false) {
        ctx.fill(Shapes.head, with: .color(fur.base))
        do { // 模様は頭の形の内側だけに塗る
            var inside = ctx
            inside.clip(to: Shapes.head)
            switch fur.pattern {
            case 1:
                inside.fill(Shapes.mikeOrange, with: .color(Color(hex: 0xF2A65A)))
                inside.fill(Shapes.mikeBlack, with: .color(Color(hex: 0x4A3F45)))
            case 2:
                stroke(&inside, Shapes.stripesHead, fur.stripe, 3.6)
                stroke(&inside, Shapes.stripesCheek, fur.stripe, 3.4)
            case 3:
                inside.fill(Shapes.hachiWhite, with: .color(.white))
            default:
                break
            }
            // 絵本の塗りのような、やわらかい光
            var light = inside
            light.translateBy(x: 40, y: 38)
            light.rotate(by: .degrees(-12))
            light.opacity = fur.dark ? 0.07 : 0.22
            light.fill(ellipse(0, 0, 14, 8), with: .color(.white))
        }
        ctx.fill(Shapes.earL, with: .color(fur.earIn))
        ctx.fill(Shapes.earR, with: .color(fur.earIn))
        if fur.pattern != 3 {
            if fur.dark {
                ctx.fill(Shapes.muzzle, with: .color(Color(hex: 0x4C424A)))
            } else {
                ctx.fill(Shapes.muzzle, with: .color(Color.white.opacity(0.55)))
            }
        }
        stroke(&ctx, Shapes.head, Shapes.outline, 2.4)
        let blushStrength = fur.dark ? 0.55 : 0.6
        blush(&ctx, 26, 69, strength: blushStrength)
        blush(&ctx, 74, 69, strength: blushStrength)
        if happy {
            stroke(&ctx, Shapes.happyEyes, Shapes.outline, 2.6)
        } else {
            let rx: CGFloat = bigEyes ? 6 : 4.4
            let ry: CGFloat = bigEyes ? 7 : 5.4
            let shine: CGFloat = bigEyes ? 2.3 : 1.8
            let sparkle: CGFloat = bigEyes ? 1.1 : 0.85
            let eyeColor = fur.dark ? Color(hex: 0x1E1A1E) : Color(hex: 0x3B2C2A)
            for cx in [CGFloat(36), CGFloat(64)] {
                let eye = ellipse(cx, 58, rx, ry)
                ctx.fill(eye, with: .color(eyeColor))
                if fur.dark {
                    ctx.stroke(eye, with: .color(Color(hex: 0xE9D9A6)), lineWidth: 1)
                }
                ctx.fill(ellipse(cx + 1.5, 55.6, shine, shine), with: .color(.white))
                ctx.fill(ellipse(cx - 1.6, 60.8, sparkle, sparkle), with: .color(.white))
            }
        }
        if lashes {
            stroke(&ctx, Shapes.lashes, Shapes.outline, 1.7)
        }
        ctx.fill(Shapes.nose, with: .color(Color(hex: 0xF49AAE)))
        ctx.stroke(Shapes.nose, with: .color(Color(hex: 0xC9677F)), style: StrokeStyle(lineWidth: 0.9, lineJoin: .round))
        let mouthColor = fur.dark && fur.pattern != 3 ? Color(hex: 0xE9DDE6) : Shapes.outline
        stroke(&ctx, Shapes.mouth, mouthColor, 1.8)
        stroke(&ctx, Shapes.whiskers, fur.whisker, 1.4)
    }

    /// 100×100 の座標で描いて、size に合わせて拡大する
    static func draw(kind: Int, in context: inout GraphicsContext, size: CGSize) {
        var ctx = context
        let scale = min(size.width, size.height) / 100
        ctx.translateBy(x: (size.width - 100 * scale) / 2, y: (size.height - 100 * scale) / 2)
        ctx.scaleBy(x: scale, y: scale)

        if kind == joker { // 招き猫：にっこり目、赤い首輪と鈴、上げた手
            face(&ctx, fur: furs[0], happy: true)
            stroke(&ctx, Shapes.manekiCollar, Color(hex: 0xE5525C), 5.2)
            bell(&ctx, 50, 90.5, 5.2)
            fillOutlined(&ctx, Shapes.manekiPaw, Color(hex: 0xFFF8EC), 2.2)
            let pad = Color(hex: 0xFFA9BF)
            ctx.fill(ellipse(11, 43.5, 3.6, 3), with: .color(pad))
            for p in [CGPoint(x: 7, y: 37.8), CGPoint(x: 11, y: 35.8), CGPoint(x: 15, y: 37.8)] {
                ctx.fill(ellipse(p.x, p.y, 1.6, 1.8), with: .color(pad))
            }
            return
        }

        let fur = furs[familyOf(kind)]
        let accent = accessoryColors[familyOf(kind)]
        switch roleOf(kind) {
        case 2: // 子猫：顔が小さく目が大きい。首に鈴
            var small = ctx
            small.translateBy(x: 8, y: 7.5)
            small.scaleBy(x: 0.84, y: 0.84)
            face(&small, fur: fur, bigEyes: true)
            stroke(&ctx, Shapes.kittenCollar, accent, 4.4)
            bell(&ctx, 50, 89.5, 4.8)
        case 0: // パパ：蝶ネクタイ
            face(&ctx, fur: fur)
            fillOutlined(&ctx, Shapes.bowL, accent)
            fillOutlined(&ctx, Shapes.bowR, accent)
            fillOutlined(&ctx, ellipse(50, 91.5, 3.8, 4), accent)
            stroke(&ctx, Shapes.bowFolds, Shapes.outline.opacity(0.5), 1)
        default: // ママ：リボンとまつげ
            face(&ctx, fur: fur, lashes: true)
            stroke(&ctx, Shapes.ribbonTails, accent, 3)
            fillOutlined(&ctx, Shapes.ribbonL, accent)
            fillOutlined(&ctx, Shapes.ribbonR, accent)
            fillOutlined(&ctx, ellipse(70, 22.5, 3.2, 3.2), accent)
        }
    }
}

struct CatFace: View {
    let kind: Int

    var body: some View {
        Canvas { context, size in
            CatPainter.draw(kind: kind, in: &context, size: size)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// 肉球マーク（おすすめ）
struct PawIcon: View {
    var color: Color = Palette.pinkInk

    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height) / 24
            func dot(_ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
                Path(ellipseIn: CGRect(x: (x - rx) * s, y: (y - ry) * s, width: rx * 2 * s, height: ry * 2 * s))
            }
            for p in [dot(12, 15.6, 5.6, 4.7), dot(5.4, 10, 2.3, 2.3), dot(9.5, 6.1, 2.4, 2.4), dot(14.5, 6.1, 2.4, 2.4), dot(18.6, 10, 2.3, 2.3)] {
                context.fill(p, with: .color(color))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
