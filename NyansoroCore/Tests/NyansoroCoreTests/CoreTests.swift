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
                a = chooseAction(s, s.current, level: p.level, rand: { r.nextUnit() })
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

final class DailyTests: XCTestCase {
    private let human = PlayerSetup(name: "キミ", isHuman: true, level: 0, avatar: 2)

    func testSameDaySameDeal() {
        let a = Daily.makeState(day: 9_800, human: human)
        let b = Daily.makeState(day: 9_800, human: human)
        let c = Daily.makeState(day: 9_801, human: human)
        XCTAssertEqual(a.wall.map(\.id), b.wall.map(\.id))
        XCTAssertEqual(a.players[0].hand, b.players[0].hand)
        XCTAssertNotEqual(a.wall.map(\.id), c.wall.map(\.id))
        XCTAssertEqual(a.rules.rounds, 1)
    }

    func testDayNumberIsConsecutive() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let d1 = cal.date(from: DateComponents(year: 2026, month: 11, day: 13, hour: 23, minute: 59))!
        let d2 = cal.date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 0, minute: 1))!
        XCTAssertEqual(Daily.dayNumber(d2, calendar: cal) - Daily.dayNumber(d1, calendar: cal), 1)
    }

    func testStreak() {
        var s = StreakState()
        XCTAssertEqual(s.status(today: 100), .notStarted)
        s.complete(today: 100)
        XCTAssertEqual(s.current, 1)
        s.complete(today: 100)
        XCTAssertEqual(s.current, 1, "same day twice does not count")
        s.complete(today: 101)
        XCTAssertEqual(s.current, 2)
        XCTAssertEqual(s.status(today: 102), .keepGoing)
        XCTAssertEqual(s.status(today: 103), .revivable)
        XCTAssertEqual(s.displayCount(today: 103), 2)
        XCTAssertTrue(s.revive(today: 103))
        s.complete(today: 103)
        XCTAssertEqual(s.current, 3, "revived streak continues")
        XCTAssertEqual(s.status(today: 106), .broken)
        XCTAssertEqual(s.displayCount(today: 106), 0)
        XCTAssertFalse(s.revive(today: 106))
        s.complete(today: 106)
        XCTAssertEqual(s.current, 1)
        XCTAssertEqual(s.best, 3)
    }
}

final class FeedbackTests: XCTestCase {
    private func setups() -> [PlayerSetup] {
        (0..<4).map { PlayerSetup(name: "p\($0)", isHuman: $0 == 0, level: 1, avatar: 0) }
    }

    func testNearMissWhenSomeoneElseWins() {
        var s = GameState(setups: setups(), rules: Rules(rounds: 1, furikomiPenalty: 0), seed: 5)
        var id = 5000
        func t(_ k: Int) -> Tile { id += 1; return Tile(id: id, kind: k) }
        s.players[0].hand = [0, 0, 0, 3, 4, 5, 8, 8].map(t)          // あと1枚（白の子猫待ち）
        s.players[1].hand = [9, 9, 9, 12, 12, 12, 15, 15, 15].map(t)
        s.current = 1
        s.phase = .discard
        XCTAssertTrue(s.apply(.tsumo))
        XCTAssertEqual(Feedback.roundMessage(s), "惜《お》しい！ あと1枚《まい》だった！")
    }

    func testPraiseWhenIWin() {
        var s = GameState(setups: setups(), rules: Rules(rounds: 1, furikomiPenalty: 0), seed: 5)
        var id = 6000
        func t(_ k: Int) -> Tile { id += 1; return Tile(id: id, kind: k) }
        s.players[0].hand = [0, 0, 0, 3, 3, 3, 6, 6, 6].map(t)
        s.phase = .discard
        s.current = 0
        XCTAssertTrue(s.apply(.tsumo))
        XCTAssertEqual(Feedback.roundMessage(s), "全部《ぜんぶ》同《おな》じ猫《ねこ》！ お見事《みごと》！")
        XCTAssertEqual(Feedback.winTurns(s, seat: 0), 1)
    }
}

final class MissionTests: XCTestCase {
    private func setups() -> [PlayerSetup] {
        (0..<4).map { PlayerSetup(name: "p\($0)", isHuman: $0 == 0, level: 1, avatar: 0) }
    }

    func testPerfectWinCompletesSeveralMissions() {
        var s = GameState(setups: setups(), rules: Rules(rounds: 1, furikomiPenalty: 0), seed: 5)
        var id = 7000
        func t(_ k: Int) -> Tile { id += 1; return Tile(id: id, kind: k) }
        s.players[0].hand = [0, 0, 0, 3, 3, 3, 6, 6, 6].map(t)
        s.phase = .discard
        s.current = 0
        XCTAssertTrue(s.apply(.tsumo))
        var p = MissionProgress()
        var stats = PlayStats()
        let done = MissionTracker.roundEnded(s, progress: &p, stats: &stats).map(\.id)
        XCTAssertEqual(Set(done), [.firstWin, .tsumoWin, .noJokerWin, .allSameWin, .fastWin, .bigWin, .perfectWin, .roleWin])
        XCTAssertEqual(stats.wins, 1)
        XCTAssertEqual(stats.bestPoints, 45) // パパそろい +15
        XCTAssertEqual(stats.fastestWin, 1)
        XCTAssertEqual(p.count(.wins10), 1)
        XCTAssertTrue(MissionTracker.roundEnded(s, progress: &p, stats: &stats).isEmpty, "achieved missions are not repeated")
        XCTAssertNotNil(p.latestBadge)
    }

    func testStreakMissions() {
        var p = MissionProgress()
        XCTAssertTrue(MissionTracker.streakUpdated(2, progress: &p).isEmpty)
        XCTAssertEqual(MissionTracker.streakUpdated(3, progress: &p).map(\.id), [.streak3])
        XCTAssertTrue(MissionTracker.streakUpdated(1, progress: &p).isEmpty, "a broken streak does not lower progress")
        XCTAssertEqual(p.count(.streak7), 3)
    }

    func testGradeAndWaitPoints() {
        var s = GameState(setups: setups(), rules: Rules(rounds: 1, furikomiPenalty: 0), seed: 5)
        var id = 8000
        func t(_ k: Int) -> Tile { id += 1; return Tile(id: id, kind: k) }
        // 三毛パパ×3・黒の家族2匹・白の子猫×2・茶トラのママ ＋ 黒の子猫を引いた
        s.players[0].hand = [0, 0, 0, 3, 4, 8, 8, 10, 5].map(t)
        s.phase = .discard
        s.current = 0
        XCTAssertEqual(Coaching.grade(s, seat: 0, discarding: 10), .best)
        XCTAssertEqual(Coaching.grade(s, seat: 0, discarding: 0), .miss)
        let hand8 = s.players[0].hand.filter { $0.kind != 10 }
        let pts = Coaching.waitPoints(hand8: hand8)!
        XCTAssertEqual(pts.min, 10, "白の子猫か招き猫でロン：混ざった形なので上がりの10点")
        XCTAssertEqual(pts.max, 20, "白の子猫を自分で引けば 10＋5＋招き猫なし5")
    }
}
