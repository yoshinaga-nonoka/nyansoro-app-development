import XCTest
@testable import NyansoroCore

private var nextId = 1000
private func tiles(_ kinds: Int...) -> [Tile] {
    kinds.map { k in
        nextId += 1
        return Tile(id: nextId, kind: k)
    }
}
private func P(_ f: Int) -> Int { kindOf(f, 0) }
private func M(_ f: Int) -> Int { kindOf(f, 1) }
private func K(_ f: Int) -> Int { kindOf(f, 2) }

private func cpuSetups(_ levels: [Int]) -> [PlayerSetup] {
    levels.enumerated().map { PlayerSetup(name: "p\($0.offset)", isHuman: false, level: $0.element, avatar: 0) }
}

final class JudgeTests: XCTestCase {
    func testSameTriplesWin() {
        XCTAssertTrue(isWinningHand(countKinds(tiles(P(0), P(0), P(0), M(1), M(1), M(1), K(2), K(2), K(2)))))
    }

    func testFamilySetsWin() {
        XCTAssertTrue(isWinningHand(countKinds(tiles(P(0), M(0), K(0), P(3), M(3), K(3), P(5), P(5), P(5)))))
    }

    func testMixedFamiliesDoNotWin() {
        XCTAssertFalse(isWinningHand(countKinds(tiles(P(0), M(1), K(2), P(3), P(3), P(3), P(5), P(5), P(5)))))
    }

    func testJokerIsWild() {
        XCTAssertTrue(isWinningHand(countKinds(tiles(P(0), P(0), joker, P(1), M(1), joker, K(2), K(2), K(2)))))
    }

    func testDistanceAndWaits() {
        let hand = countKinds(tiles(P(0), P(0), P(0), P(1), M(1), K(1), K(2), K(2)))
        XCTAssertEqual(distance(hand), 1)
        XCTAssertEqual(waitingKinds(hand), [K(2), joker])
    }

    func testArrangePutsCompleteSetsFirst() {
        let a = arrange(tiles(K(2), P(0), P(1), P(0), M(1), P(0), K(1), M(4)))
        XCTAssertTrue(a.groups[0].complete)
        XCTAssertEqual(a.groups.filter(\.complete).count, 2)
        XCTAssertEqual(a.leftovers.map(\.kind).sorted(), [K(2), M(4)].sorted())
    }
}

final class ScoreTests: XCTestCase {
    func testAllSameNoJokerTsumo() {
        let w = scoreWin(tiles(P(0), P(0), P(0), M(1), M(1), M(1), K(2), K(2), K(2)), tsumo: true)!
        XCTAssertEqual(w.total, 10 + 5 + 5 + 10)
    }

    func testAllFamilyRon() {
        let w = scoreWin(tiles(P(0), M(0), K(0), P(3), M(3), K(3), P(5), M(5), K(5)), tsumo: false)!
        XCTAssertEqual(w.total, 10 + 5 + 10)
    }

    func testMixedWithJokerIsBaseOnly() {
        let w = scoreWin(tiles(P(0), M(0), joker, P(3), P(3), P(3), K(5), K(5), K(5)), tsumo: false)!
        XCTAssertEqual(w.total, 10)
    }
}

final class GameTests: XCTestCase {
    private func playMatch(seed: UInt32, levels: [Int] = [3, 2, 1, 4]) -> GameState {
        var s = GameState(setups: cpuSetups(levels), rules: Rules(rounds: 4, furikomiPenalty: 5), seed: seed)
        var r = Mulberry32(seed: seed &+ 99)
        var guardCount = 0
        while s.phase != .matchEnd, guardCount < 5000 {
            guardCount += 1
            let a: Action
            switch s.phase {
            case .draw: a = .draw
            case .discard:
                let p = s.players[s.current]
                a = canWin(p.hand) ? .tsumo : .discard(tileId: chooseDiscard(s, s.current, level: p.level, rand: { r.nextUnit() }))
            case .claim: a = .ron(player: s.claimQueue[0])
            default: a = .nextRound
            }
            XCTAssertTrue(s.apply(a), "action \(a) should be valid in phase \(s.phase)")
            if s.phase != .matchEnd {
                let n = s.wall.count + s.players.reduce(0) { $0 + $1.hand.count + $1.discards.count }
                XCTAssertEqual(n, totalTiles, "tiles must be conserved")
            }
        }
        return s
    }

    func testMatchesFinishAndConserveTiles() {
        for seed in UInt32(1)...6 {
            let s = playMatch(seed: seed)
            XCTAssertEqual(s.phase, .matchEnd)
            XCTAssertEqual(s.history.count, 4)
            XCTAssertEqual((0..<4).map { s.place(of: $0) }.sorted(), [0, 1, 2, 3])
        }
    }

    func testSameSeedSameWall() {
        let a = GameState(setups: cpuSetups([1, 1, 1, 1]), rules: Rules(rounds: 1, furikomiPenalty: 0), seed: 42)
        let b = GameState(setups: cpuSetups([1, 1, 1, 1]), rules: Rules(rounds: 1, furikomiPenalty: 0), seed: 42)
        XCTAssertEqual(a.wall.map(\.id), b.wall.map(\.id))
    }

    func testClosestPlayerClaimsFirst() {
        var s = GameState(setups: cpuSetups([1, 1, 1, 1]), rules: Rules(rounds: 1, furikomiPenalty: 5), seed: 7)
        s.players[0].hand = tiles(P(4), M(4), K(4), P(5), M(5), K(5), K(2), K(2), M(0))
        s.players[1].hand = tiles(P(0), M(1), K(2), P(3), M(4), K(5), P(1), M(2))
        s.players[2].hand = tiles(P(0), P(0), P(0), M(1), M(1), M(1), K(3), K(3))
        s.players[3].hand = tiles(P(1), P(1), P(1), M(2), M(2), M(2), K(3), K(3))
        let target = tiles(K(3))[0]
        s.players[0].hand.append(target)
        s.phase = .discard
        s.current = 0
        XCTAssertTrue(s.apply(.discard(tileId: target.id)))
        XCTAssertEqual(s.phase, .claim)
        XCTAssertEqual(s.claimQueue, [2, 3])
        XCTAssertTrue(s.apply(.ron(player: 2)))
        XCTAssertEqual(s.result?.winner, 2)
        XCTAssertEqual(s.result?.deltas[0], -5)
    }

    func testCodableRoundTrip() throws {
        let s = playMatch(seed: 3)
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(GameState.self, from: data)
        XCTAssertEqual(back, s)
    }
}

final class TutorialTests: XCTestCase {
    func testTutorialScript() {
        let deck = Tutorial.deck()
        XCTAssertEqual(deck.count, totalTiles)
        var setups = cpuSetups([0, 1, 1, 1])
        setups[0].isHuman = true
        var s = GameState(setups: setups, rules: Rules(rounds: 1, furikomiPenalty: 0), seed: 1, presetDeck: deck)
        XCTAssertTrue(s.apply(.draw))
        XCTAssertEqual(recommendDiscard(s, 0), Tutorial.discardKind)
        let t = s.players[0].hand.first { $0.kind == Tutorial.discardKind }!
        XCTAssertTrue(s.apply(.discard(tileId: t.id)))
        XCTAssertEqual(waitingKinds(countKinds(s.players[0].hand)), [Tutorial.winKind, joker])
        XCTAssertTrue(s.apply(.draw))
        let w = s.players[1].hand.first { $0.kind == Tutorial.winKind }!
        XCTAssertTrue(s.apply(.discard(tileId: w.id)))
        XCTAssertEqual(s.claimQueue, [0])
    }
}

final class RubyTests: XCTestCase {
    func testParse() {
        XCTAssertEqual(parseRuby("猫《ねこ》を3枚《まい》"), [.ruby(base: "猫", reading: "ねこ"), .text("を3"), .ruby(base: "枚", reading: "まい")])
        XCTAssertEqual(parseRuby("茶《ちゃ》トラの子猫《こねこ》"), [.ruby(base: "茶", reading: "ちゃ"), .text("トラの"), .ruby(base: "子猫", reading: "こねこ")])
        XCTAssertEqual(parseRuby("｜CPU《シーピーユー》と"), [.ruby(base: "CPU", reading: "シーピーユー"), .text("と")])
        XCTAssertEqual(parseRuby("ふりがな なし"), [.text("ふりがな なし")])
    }

    func testPlain() {
        XCTAssertEqual(plainText("三毛《みけ》のパパを捨《す》てる"), "三毛のパパを捨てる")
    }
}

final class ProgressTests: XCTestCase {
    func testRankUpAndCrown() {
        var p = RankProgress()
        XCTAssertFalse(p.addStars(2).rankedUp)
        let r = p.addStars(1)
        XCTAssertTrue(r.rankedUp)
        XCTAssertEqual(p.rank, 1)
        XCTAssertEqual(p.stars, 0)
        p.rank = Ranks.all.count - 1
        p.stars = 5
        XCTAssertTrue(p.addStars(2).crowned)
        XCTAssertEqual(p.crowns, 1)
    }
}

final class AdPolicyTests: XCTestCase {
    func testNoAdsInFirstMatches() {
        var a = AdPolicy()
        for _ in 0..<AdPolicy.freeMatches {
            a.recordMatchFinished()
            XCTAssertFalse(a.canShowInterstitial())
        }
        a.recordMatchFinished()
        XCTAssertTrue(a.canShowInterstitial())
        a.recordInterstitial()
        a.recordMatchFinished()
        XCTAssertFalse(a.canShowInterstitial(), "every other match at most")
        a.recordMatchFinished()
        XCTAssertFalse(a.canShowInterstitial(), "needs 3 minutes gap")
        XCTAssertTrue(a.canShowInterstitial(now: Date().addingTimeInterval(200)))
    }

    func testRewardsPerDay() {
        var a = AdPolicy()
        for _ in 0..<AdPolicy.freeMatches { a.recordMatchFinished() }
        for _ in 0..<AdPolicy.rewardsPerDay {
            XCTAssertTrue(a.canOfferReward())
            a.recordReward()
        }
        XCTAssertFalse(a.canOfferReward())
        XCTAssertTrue(a.canOfferReward(now: Date().addingTimeInterval(86_400 * 2)))
    }
}
