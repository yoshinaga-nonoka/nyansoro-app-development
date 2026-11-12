// CPUの強さのバランス確認：主人公CPU 1人 vs 相手CPU 3人で4局の試合をくり返し、1位になる割合を出す。
// 使い方: swift run -c release nyansoro-sim [試合数] [主人公レベル,...] [ランク番号,...]

import NyansoroCore

let args = CommandLine.arguments
let n = args.count > 1 ? Int(args[1]) ?? 60 : 60
let heroes = args.count > 2 ? args[2].split(separator: ",").compactMap { Int($0) } : [2, 3]
let rankFilter = args.count > 3 ? Set(args[3].split(separator: ",").compactMap { Int($0) }) : Set(0..<Ranks.all.count)

func playMatch(hero: Int, rank: RankDef, seed: UInt32) -> (place: Int, turns: Int, exhausted: Int) {
    var r = Mulberry32(seed: seed &* 7919)
    let setups = [hero, rank.level, rank.level, rank.level].enumerated().map {
        PlayerSetup(name: "p\($0.offset)", isHuman: false, level: $0.element, avatar: 0)
    }
    var s = GameState(setups: setups, rules: Rules(rounds: 4, furikomiPenalty: rank.furikomiPenalty), seed: seed)
    var turns = 0
    var exhausted = 0
    while s.phase != .matchEnd {
        let a: Action
        switch s.phase {
        case .draw: a = .draw
        case .discard:
            let p = s.players[s.current]
            a = canWin(p.hand) ? .tsumo : .discard(tileId: chooseDiscard(s, s.current, level: p.level, rand: { r.nextUnit() }))
        case .claim: a = .ron(player: s.claimQueue[0])
        default:
            turns += s.turn
            if s.result?.kind == .exhausted { exhausted += 1 }
            a = .nextRound
        }
        s.apply(a)
    }
    return (s.place(of: 0), turns, exhausted)
}

print("各 \(n) 試合（4局）／ 数字 = 主人公CPUが1位になった割合（運だけなら25%）")
for h in heroes {
    var row = "Lv\(h)  "
    for (ri, rank) in Ranks.all.enumerated() where rankFilter.contains(ri) {
        var first = 0
        for i in 0..<n where playMatch(hero: h, rank: rank, seed: UInt32(10_000 * h + 100 * ri + i + 1)).place == 0 {
            first += 1
        }
        row += "\(plainText(rank.name)) \(first * 100 / n)%  "
    }
    print(row)
}
