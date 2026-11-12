// ふりがな記法（青空文庫式）：「猫《ねこ》」「｜CPU《シーピーユー》」。
// 画面ではルビ付きで表示し、VoiceOver など文字だけが必要なところでは plainText() で読みを外す。

public enum RubyPart: Equatable, Sendable {
    case text(String)
    case ruby(base: String, reading: String)
}

private func isKanji(_ ch: Character) -> Bool {
    guard let v = ch.unicodeScalars.first?.value else { return false }
    return (0x4E00...0x9FFF).contains(v) || (0x3400...0x4DBF).contains(v) || v == 0x3005
}

public func parseRuby(_ text: String) -> [RubyPart] {
    var parts: [RubyPart] = []
    var buffer: [Character] = []
    var pipeStart: Int?
    let chars = Array(text)
    var i = 0

    func flush(_ upTo: Int) {
        if upTo > 0 { parts.append(.text(String(buffer[0..<upTo]))) }
        buffer.removeFirst(upTo)
    }

    while i < chars.count {
        let ch = chars[i]
        if ch == "｜" {
            pipeStart = buffer.count
            i += 1
            continue
        }
        if ch == "《", let close = chars[(i + 1)...].firstIndex(of: "》") {
            let reading = String(chars[(i + 1)..<close])
            var start = buffer.count
            if let p = pipeStart {
                start = p
            } else {
                while start > 0, isKanji(buffer[start - 1]) { start -= 1 }
            }
            if start < buffer.count, !reading.isEmpty {
                let base = String(buffer[start...])
                buffer.removeSubrange(start...)
                flush(buffer.count)
                parts.append(.ruby(base: base, reading: reading))
                pipeStart = nil
                i = close + 1
                continue
            }
        }
        buffer.append(ch)
        i += 1
    }
    flush(buffer.count)
    // 隣り合う text をまとめる
    var merged: [RubyPart] = []
    for p in parts {
        if case let .text(a) = p, case let .text(b)? = merged.last {
            merged[merged.count - 1] = .text(b + a)
        } else {
            merged.append(p)
        }
    }
    return merged
}

/// 読みを外した文字列（「猫《ねこ》」→「猫」）
public func plainText(_ text: String) -> String {
    parseRuby(text).map {
        switch $0 {
        case let .text(s): return s
        case let .ruby(base, _): return base
        }
    }.joined()
}
