import XCTest
@testable import NyansoroCore

private var nextId = 5000
private func tiles(_ kinds: Int...) -> [Tile] {
    kinds.map { k in
        nextId += 1
        return Tile(id: nextId, kind: k)
    }
}
private func P(_ f: Int) -> Int { kindOf(f, 0) }
private func M(_ f: Int) -> Int { kindOf(f, 1) }
private func K(_ f: Int) -> Int { kindOf(f, 2) }

private func setups(human: Bool = false) -> [PlayerSetup] {
    (0..<4).map { PlayerSetup(name: "p\($0)", isHuman: human && $0 == 0, level: human && $0 == 0 ? 0 : 1, avatar: 0) }
}

final class YakuTests: XCTestCase {
    func testRolePapa() {
        let w = scoreWin(tiles(P(0), P(0), P(0), P(1), P(1), P(1), P(5), P(5), P(5)), tsumo: false)!
        XCTAssertTrue(w.items.contains(ScoreTable.rolePapa))
        XCTAssertTrue(w.items.contains(ScoreTable.allSame))
        XCTAssertEqual(w.total, 10 + 5 + 10 + 15)
    }

    func testOneFamily() {
        let w = scoreWin(tiles(P(2), P(2), P(2), M(2), M(2), M(2), K(2), K(2), K(2)), tsumo: false)!
        XCTAssertTrue(w.items.contains(ScoreTable.oneFamily))
        // 全部同じ猫（10）でも全部家族（10）でも同じ点。ひと家族だらけ +20
        XCTAssertEqual(w.total, 10 + 5 + 10 + 20)
    }

    func testFamilyAndSiblings() {
        let w = scoreWin(tiles(P(0), M(0), K(0), M(0), M(0), M(0), P(4), M(4), K(4)), tsumo: false)!
        XCTAssertTrue(w.items.contains(ScoreTable.familyAndSiblings))
        XCTAssertEqual(w.total, 10 + 5 + 5)
    }

    func testSituationYaku() {
        let hand = tiles(P(0), M(0), K(0), P(3), M(3), K(3), P(5), M(5), K(5))
        let w = scoreWin(hand, WinContext(tsumo: true, riichi: true, ippatsu: true, lastTile: true))!
        XCTAssertEqual(w.total, 10 + 5 + 10 + 5 + 10 + 5 + 10)
        // リーチしていなければ「すぐにゃん」は付かない
        let w2 = scoreWin(hand, WinContext(tsumo: false, riichi: false, ippatsu: true))!
        XCTAssertFalse(w2.items.contains(ScoreTable.ippatsu))
    }

    func testEveryItemIsListed() {
        for r in ScoreTable.rules { XCTAssertTrue(ScoreTable.all.contains(r.item)) }
        for r in ScoreTable.rules where !r.example.isEmpty {
            let w = scoreWin(r.example.map { Tile(id: Int.random(in: 0..<1_000_000), kind: $0) }, tsumo: false)
            XCTAssertNotNil(w, "example for \(r.item.label) must win")
            XCTAssertTrue(w!.items.contains(r.item), "example for \(r.item.label)")
        }
    }
}

final class RiichiTests: XCTestCase {
    /// 席0 があと1枚の形（三毛パパ×3・黒の家族・白の子猫×2 ＋ いらない茶トラのママ）を引いた状態
    private func readyState() -> (GameState, junk: Tile) {
        var s = GameState(setups: setups(), rules: Rules(rounds: 1, furikomiPenalty: 0), seed: 11)
        let junk = tiles(M(3))[0]
        s.players[0].hand = tiles(P(0), P(0), P(0), P(1), M(1), K(1), K(2), K(2)) + [junk]
        s.players[1].hand = tiles(P(4), P(4), M(5), M(5), K(3), P(3), M(4), K(5))
        s.players[2].hand = tiles(P(4), M(5), M(3), K(3), P(3), M(4), K(5), K(4))
        s.players[3].hand = tiles(P(5), P(5), M(3), K(3), P(3), M(4), K(5), K(4))
        s.wall = tiles(M(2), M(2), M(2), P(5), K(2), M(4))
        s.current = 0
        s.phase = .discard
        s.drawn = junk
        return (s, junk)
    }

    func testRiichiNeedsReadyHand() {
        var (s, junk) = readyState()
        XCTAssertEqual(s.riichiKinds(seat: 0), [M(3)])
        let papa = s.players[0].hand.first { $0.kind == P(0) }!
        XCTAssertFalse(s.canRiichi(seat: 0, discarding: papa.id))
        XCTAssertFalse(s.apply(.riichi(tileId: papa.id)))
        XCTAssertTrue(s.apply(.riichi(tileId: junk.id)))
        XCTAssertTrue(s.players[0].riichi)
        XCTAssertTrue(s.players[0].ippatsu)
    }

    func testRiichiLocksHandAndClearsIppatsu() {
        var (s, junk) = readyState()
        XCTAssertTrue(s.apply(.riichi(tileId: junk.id)))
        // 3人が引いて捨てる（上がれない猫）
        for _ in 1...3 {
            XCTAssertTrue(s.apply(.draw))
            XCTAssertTrue(s.apply(.discard(tileId: s.drawn!.id)))
            XCTAssertEqual(s.phase, .draw)
        }
        XCTAssertEqual(s.current, 0)
        XCTAssertTrue(s.apply(.draw))
        let drawn = s.drawn!
        XCTAssertEqual(drawn.kind, P(5))
        // リーチ中は引いた猫以外は捨てられない。もう一度リーチもできない
        let other = s.players[0].hand.first { $0.id != drawn.id }!
        XCTAssertFalse(s.apply(.discard(tileId: other.id)))
        XCTAssertFalse(s.apply(.riichi(tileId: drawn.id)))
        XCTAssertTrue(s.apply(.discard(tileId: drawn.id)))
        XCTAssertTrue(s.players[0].riichi)
        XCTAssertFalse(s.players[0].ippatsu, "すぐにゃんは次に捨てたら消える")
    }

    func testRiichiIppatsuTsumo() {
        var (s, junk) = readyState()
        s.wall = tiles(M(2), M(2), M(2), K(2), M(4))
        XCTAssertTrue(s.apply(.riichi(tileId: junk.id)))
        for _ in 1...3 {
            XCTAssertTrue(s.apply(.draw))
            XCTAssertTrue(s.apply(.discard(tileId: s.drawn!.id)))
            XCTAssertEqual(s.phase, .draw, "seat \(s.current) \(s.lastDiscard!.tile.kind) claim \(s.claimQueue)")
        }
        XCTAssertTrue(s.apply(.draw))
        XCTAssertTrue(s.apply(.tsumo), "hand \(s.players[0].hand.map(\.kind))")
        let items = s.result!.win!.items
        XCTAssertTrue(items.contains(ScoreTable.riichi))
        XCTAssertTrue(items.contains(ScoreTable.ippatsu))
        XCTAssertTrue(items.contains(ScoreTable.tsumo))
        XCTAssertEqual(s.result!.deltas[0], 10 + 5 + 10 + 5 + 5)
    }

    func testLastTileYaku() {
        var (s, junk) = readyState()
        XCTAssertTrue(s.apply(.discard(tileId: junk.id)))
        s.current = 3
        s.phase = .draw
        s.wall = tiles(K(2))
        // 席3 が最後の1枚を引いて捨てる → 席0 が上がる（最後の1枚）
        XCTAssertTrue(s.apply(.draw))
        XCTAssertTrue(s.wall.isEmpty)
        XCTAssertTrue(s.apply(.discard(tileId: s.drawn!.id)))
        XCTAssertEqual(s.claimQueue, [0])
        XCTAssertTrue(s.apply(.ron(player: 0)))
        XCTAssertTrue(s.result!.win!.items.contains(ScoreTable.lastTile))
    }

    func testCpuDeclaresRiichiWhenReady() {
        let (s, junk) = readyState()
        XCTAssertEqual(chooseAction(s, 0, level: 4, rand: { 0.99 }), .riichi(tileId: junk.id))
        XCTAssertEqual(chooseAction(s, 0, level: 3, rand: { 0.5 }), .riichi(tileId: junk.id))
        // 下のレベルはときどき言い忘れる
        XCTAssertEqual(chooseAction(s, 0, level: 1, rand: { 0.99 }), .discard(tileId: junk.id))
    }

    func testInsightOffersRiichi() {
        var (s, junk) = readyState()
        let ins = handInsight(s, seat: 0, recommendOn: true)!
        XCTAssertEqual(ins.rec, M(3))
        XCTAssertTrue(ins.canRiichi)
        XCTAssertTrue(s.apply(.riichi(tileId: junk.id)))
        XCTAssertTrue(handInsight(s, seat: 0, recommendOn: true)!.riichi)
    }
}

final class TutorialTaskTests: XCTestCase {
    /// 台本どおり（おすすめを捨てる・リーチできたらリーチ）に進めると、どの練習も成功する。CPU は上がらない
    func testEveryTaskCanBeCleared() {
        for task in TutorialTask.allCases {
            let deck = task.deck()
            XCTAssertEqual(deck.count, totalTiles, "\(task)")
            XCTAssertEqual(countKinds(deck.map { Tile(id: 0, kind: $0) }), makeTiles().reduce(into: [Int](repeating: 0, count: numKinds)) { $0[$1.kind] += 1 })
            var s = GameState(setups: setups(human: true), rules: Rules(rounds: 1, furikomiPenalty: 0), seed: 1, presetDeck: deck)
            var discards: [Int] = []
            var steps = 0
            var cpuScript = task == .basics
            while s.phase != .roundEnd, steps < 400 {
                steps += 1
                switch s.phase {
                case .draw:
                    s.apply(.draw)
                case .discard:
                    if s.current == 0 {
                        if canWin(s.players[0].hand) { s.apply(.tsumo); continue }
                        let rec = handInsight(s, seat: 0, recommendOn: true)!.rec!
                        let t = s.players[0].hand.last { $0.kind == rec }!
                        discards.append(rec)
                        if task == .riichi, s.canRiichi(seat: 0, discarding: t.id) {
                            XCTAssertTrue(s.apply(.riichi(tileId: t.id)))
                        } else {
                            XCTAssertTrue(s.apply(.discard(tileId: t.id)))
                        }
                    } else if cpuScript, s.current == 1, let t = s.players[1].hand.first(where: { $0.kind == Tutorial.winKind }) {
                        cpuScript = false
                        s.apply(.discard(tileId: t.id))
                    } else {
                        // 練習では CPU は上がらない
                        let id = chooseDiscard(s, s.current, level: 1, rand: { 0.7 })
                        s.apply(.discard(tileId: id))
                    }
                case .claim:
                    let head = s.claimQueue[0]
                    s.apply(head == 0 ? .ron(player: 0) : .pass(player: head))
                default:
                    break
                }
            }
            XCTAssertTrue(task.isCleared(s.result), "\(task) should be cleared: \(String(describing: s.result))")
            XCTAssertEqual(Array(discards.prefix(task.discardKinds.count)), task.discardKinds, "\(task)")
        }
    }
}
