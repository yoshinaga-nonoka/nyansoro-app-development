// 猫の絵柄。Web版のSVG（100×100の座標）をそのまま Path にして Canvas で描く。
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
    static let outline = Color(hex: 0x4A3B48)
    static let head = SVGPath.parse("M16 50 C14 36 16 22 22 12 C28 16 36 24 41 29 C47 27 53 27 59 29 C64 24 72 16 78 12 C84 22 86 36 84 50 C90 72 72 88 50 88 C28 88 10 72 16 50 Z")
    static let earL = SVGPath.parse("M23 19 C26 23 31 27 35 30 C30 32 25 34 21 37 C20 31 21 25 23 19 Z")
    static let earR = SVGPath.parse("M77 19 C74 23 69 27 65 30 C70 32 75 34 79 37 C80 31 79 25 77 19 Z")
    static let mikeOrange = SVGPath.parse("M16 50 C14 36 16 22 22 12 C28 16 36 24 41 29 C44 35 41 44 33 47 C25 50 19 53 16 50 Z")
    static let mikeBlack = SVGPath.parse("M59 29 C64 24 72 16 78 12 C84 22 86 36 84 50 C79 49 72 45 67 40 C62 36 60 32 59 29 Z")
    static let hachiWhite = SVGPath.parse("M50 36 C47 46 43 55 37 62 C31 69 31 79 40 84 C46 87 54 87 60 84 C69 79 69 69 63 62 C57 55 53 46 50 36 Z")
    static let stripesHead = SVGPath.parse("M44 33 L45.5 41 M50 31 L50 41 M56 33 L54.5 41")
    static let stripesCheek = SVGPath.parse("M16.5 57 L25 58.5 M17.5 64 L25 64.5 M83.5 57 L75 58.5 M82.5 64 L75 64.5")
    static let nose = SVGPath.parse("M46.5 64 L53.5 64 L50 68 Z")
    static let mouth = SVGPath.parse("M43 69.5 Q46.5 74.5 50 69.5 Q53.5 74.5 57 69.5")
    static let whiskers = SVGPath.parse("M5 61 L21 63 M5 68 L21 67.5 M95 61 L79 63 M95 68 L79 67.5")
    static let happyEyes = SVGPath.parse("M29 58 Q36 50 43 58 M57 58 Q64 50 71 58")
    static let bowL = SVGPath.parse("M50 91 L36 84 L36 98 Z")
    static let bowR = SVGPath.parse("M50 91 L64 84 L64 98 Z")
    static let ribbonL = SVGPath.parse("M68 24 C60 13 52 22 59 28.5 C62 31 66 27.5 68 24 Z")
    static let ribbonR = SVGPath.parse("M68 24 C74 11 85 16 79.5 25.5 C76.5 30.5 71 28 68 24 Z")
    static let lashes = SVGPath.parse("M29.6 50.5 L25.5 47.5 M70.4 50.5 L74.5 47.5")
    static let kittenCollar = SVGPath.parse("M31 82 Q50 90 69 82")
    static let manekiCollar = SVGPath.parse("M28 84 Q50 93 72 84")
}

private struct Fur {
    let base: Color
    let earIn: Color
    let eye: Color
    let whisker: Color
    let mouth: Color
    let blush: Double
    let pattern: Int // 0なし 1三毛 2しま 3ハチワレ
    let stripe: Color
}

private let furs: [Fur] = [
    Fur(base: Color(hex: 0xFFFAF2), earIn: Color(hex: 0xF7A8BD), eye: Color(hex: 0xE7A93A), whisker: Color(hex: 0x8A7B86), mouth: Shapes.outline, blush: 0.55, pattern: 1, stripe: .clear),
    Fur(base: Color(hex: 0x2F2A33), earIn: Color(hex: 0x7A5566), eye: Color(hex: 0xF2CF3C), whisker: Color(hex: 0xCFC6D6), mouth: Color(hex: 0xE7DCEF), blush: 0.35, pattern: 0, stripe: .clear),
    Fur(base: Color(hex: 0xFFFFFF), earIn: Color(hex: 0xF7A8BD), eye: Color(hex: 0x5AA9E6), whisker: Color(hex: 0x9A8FA0), mouth: Shapes.outline, blush: 0.55, pattern: 0, stripe: .clear),
    Fur(base: Color(hex: 0xF5A457), earIn: Color(hex: 0xF7A8BD), eye: Color(hex: 0x8CC152), whisker: Color(hex: 0x8A5A2E), mouth: Shapes.outline, blush: 0.5, pattern: 2, stripe: Color(hex: 0xD4701F)),
    Fur(base: Color(hex: 0xA9ADB8), earIn: Color(hex: 0xF0B3C4), eye: Color(hex: 0x76C46A), whisker: Color(hex: 0x4F5460), mouth: Shapes.outline, blush: 0.5, pattern: 2, stripe: Color(hex: 0x5B606C)),
    Fur(base: Color(hex: 0x2F2A33), earIn: Color(hex: 0x7A5566), eye: Color(hex: 0xE7A93A), whisker: Color(hex: 0xCFC6D6), mouth: Shapes.outline, blush: 0.45, pattern: 3, stripe: .clear),
]

private let accessoryColors: [Color] = [
    Color(hex: 0xF07D8C), Color(hex: 0xA77BE0), Color(hex: 0x5FAEE6), Color(hex: 0xF29A4A), Color(hex: 0x4DBE85), Color(hex: 0xE8B931),
]

enum CatPainter {
    private static func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
    }

    private static func stroke(_ ctx: inout GraphicsContext, _ path: Path, _ color: Color, _ width: CGFloat) {
        ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    private static func face(_ ctx: inout GraphicsContext, fur: Fur, bigEyes: Bool, happy: Bool) {
        ctx.fill(Shapes.head, with: .color(fur.base))
        switch fur.pattern {
        case 1:
            ctx.fill(Shapes.mikeOrange, with: .color(Color(hex: 0xF0A04B)))
            ctx.fill(Shapes.mikeBlack, with: .color(Color(hex: 0x3B3236)))
        case 2:
            stroke(&ctx, Shapes.stripesHead, fur.stripe, 3.4)
            stroke(&ctx, Shapes.stripesCheek, fur.stripe, 3.4)
        case 3:
            ctx.fill(Shapes.hachiWhite, with: .color(.white))
        default:
            break
        }
        ctx.fill(Shapes.earL, with: .color(fur.earIn))
        ctx.fill(Shapes.earR, with: .color(fur.earIn))
        stroke(&ctx, Shapes.head, Shapes.outline, 2.6)
        let blush = Color(hex: 0xFF8FB1).opacity(fur.blush)
        ctx.fill(ellipse(27, 67, 6, 3.4), with: .color(blush))
        ctx.fill(ellipse(73, 67, 6, 3.4), with: .color(blush))
        if happy {
            stroke(&ctx, Shapes.happyEyes, Shapes.outline, 2.8)
        } else {
            let rx: CGFloat = bigEyes ? 8 : 6.6
            let ry: CGFloat = bigEyes ? 9 : 7.6
            for cx in [CGFloat(36), CGFloat(64)] {
                let iris = ellipse(cx, 56, rx, ry)
                ctx.fill(iris, with: .color(fur.eye))
                ctx.stroke(iris, with: .color(Shapes.outline), lineWidth: 1.3)
                ctx.fill(ellipse(cx, 56.5, rx * 0.56, ry * 0.8), with: .color(Color(hex: 0x2A2230)))
                let r: CGFloat = bigEyes ? 2.7 : 2.2
                ctx.fill(ellipse(cx + 2.2, 52.6, r, r), with: .color(.white))
                ctx.fill(ellipse(cx - 2, 59.5, 1, 1), with: .color(.white))
            }
        }
        ctx.fill(Shapes.nose, with: .color(Color(hex: 0xF38AA6)))
        ctx.stroke(Shapes.nose, with: .color(Color(hex: 0xC75F7E)), style: StrokeStyle(lineWidth: 1, lineJoin: .round))
        stroke(&ctx, Shapes.mouth, fur.mouth, 2)
        stroke(&ctx, Shapes.whiskers, fur.whisker, 1.6)
    }

    /// 100×100 の座標で描いて、size に合わせて拡大する
    static func draw(kind: Int, in context: inout GraphicsContext, size: CGSize) {
        var ctx = context
        let scale = min(size.width, size.height) / 100
        ctx.translateBy(x: (size.width - 100 * scale) / 2, y: (size.height - 100 * scale) / 2)
        ctx.scaleBy(x: scale, y: scale)

        if kind == joker {
            face(&ctx, fur: furs[0], bigEyes: false, happy: true)
            stroke(&ctx, Shapes.manekiCollar, Color(hex: 0xE0434C), 5.5)
            ctx.fill(ellipse(50, 91, 5.4, 5.4), with: .color(Color(hex: 0xF6C33B)))
            ctx.stroke(ellipse(50, 91, 5.4, 5.4), with: .color(Color(hex: 0x9B6B00)), lineWidth: 1.3)
            let paw = ellipse(11, 43, 9, 11)
            ctx.fill(paw, with: .color(.white))
            ctx.stroke(paw, with: .color(Shapes.outline), lineWidth: 2.2)
            let pad = Color(hex: 0xFF9FBD)
            ctx.fill(ellipse(11, 47, 3.6, 2.8), with: .color(pad))
            for p in [CGPoint(x: 7.2, y: 40.5), CGPoint(x: 11, y: 38.6), CGPoint(x: 14.8, y: 40.5)] {
                ctx.fill(ellipse(p.x, p.y, 1.6, 1.6), with: .color(pad))
            }
            return
        }

        let fur = furs[familyOf(kind)]
        let accent = accessoryColors[familyOf(kind)]
        switch roleOf(kind) {
        case 2: // 子猫：顔が小さく目が大きい。首に鈴
            var small = ctx
            small.translateBy(x: 8, y: 9.9)
            small.scaleBy(x: 0.84, y: 0.84)
            face(&small, fur: fur, bigEyes: true, happy: false)
            stroke(&ctx, Shapes.kittenCollar, accent, 4.5)
            ctx.fill(ellipse(50, 90, 5, 5), with: .color(Color(hex: 0xF6C33B)))
            ctx.stroke(ellipse(50, 90, 5, 5), with: .color(Color(hex: 0x9B6B00)), lineWidth: 1.3)
        case 0: // パパ：蝶ネクタイ
            face(&ctx, fur: fur, bigEyes: false, happy: false)
            for p in [Shapes.bowL, Shapes.bowR] {
                ctx.fill(p, with: .color(accent))
                ctx.stroke(p, with: .color(Shapes.outline), style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
            }
            let knot = Path(roundedRect: CGRect(x: 46, y: 87, width: 8, height: 8), cornerRadius: 2.2)
            ctx.fill(knot, with: .color(accent))
            ctx.stroke(knot, with: .color(Shapes.outline), lineWidth: 1.6)
        default: // ママ：リボンとまつげ
            face(&ctx, fur: fur, bigEyes: false, happy: false)
            for p in [Shapes.ribbonL, Shapes.ribbonR, ellipse(68, 24, 3.4, 3.4)] {
                ctx.fill(p, with: .color(accent))
                ctx.stroke(p, with: .color(Shapes.outline), style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
            }
            stroke(&ctx, Shapes.lashes, Shapes.outline, 1.8)
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
