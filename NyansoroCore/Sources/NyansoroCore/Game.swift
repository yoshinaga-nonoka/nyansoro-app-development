// ゲームの進行。GameState は値型で、apply(_:) で1手ずつ進める。
// 同じコードを、CPU対戦では端末で、オンライン対戦ではサーバー（審判）で動かす想定。

public let seats = 4

public struct PlayerSetup: Codable, Sendable, Equatable {
    public var name: String
    public var isHuman: Bool
    /// CPUの強さ 1〜5（人間は 0）
    public var level: Int
    /// アイコンに使う猫
    public var avatar: Int

    public init(name: String, isHuman: Bool, level: Int, avatar: Int) {
        self.name = name
        self.isHuman = isHuman
        self.level = level
        self.avatar = avatar
    }
}

public struct PlayerState: Codable, Sendable, Equatable {
    public var setup: PlayerSetup
    public var hand: [Tile] = []
    public var discards: [Tile] = []
    public var score: Int = 0

    public var name: String { setup.name }
    public var isHuman: Bool { setup.isHuman }
    public var level: Int { setup.level }
    public var avatar: Int { setup.avatar }
}

public struct Rules: Codable, Sendable, Equatable {
    public var rounds: Int
    /// 上がり牌を捨てた人が失う点（0ならなし）
    public var furikomiPenalty: Int

    public init(rounds: Int, furikomiPenalty: Int) {
        self.rounds = rounds
        self.furikomiPenalty = furikomiPenalty
    }
}

public enum Phase: String, Codable, Sendable {
    case draw, discard, claim, roundEnd, matchEnd
}

public enum ResultKind: String, Codable, Sendable {
    case tsumo, ron, exhausted
}

public struct RoundResult: Codable, Sendable, Equatable {
    public var kind: ResultKind
    public var winner: Int?
    public var from: Int?
    public var tile: Tile?
    public var win: WinInfo?
    public var deltas: [Int]
}

public struct Discard: Codable, Sendable, Equatable {
    public var tile: Tile
    public var from: Int
}

public enum Action: Equatable, Sendable {
    case draw
    case discard(tileId: Int)
    case tsumo
    case ron(player: Int)
    case pass(player: Int)
    case nextRound
}

public enum GameError: Error {
    case badPreset(String)
}

public struct GameState: Codable, Sendable, Equatable {
    public var rules: Rules
    public var round = 0
    public var dealer = 0
    public var current = 0
    public var phase: Phase = .draw
    public var players: [PlayerState]
    public var wall: [Tile] = []
    public var lastDiscard: Discard?
    /// 捨て牌で上がれる人（順番が近い人から）
    public var claimQueue: [Int] = []
    public var drawn: Tile?
    public var result: RoundResult?
    public var history: [RoundResult] = []
    public var rng: Mulberry32
    public var presetDeck: [Int]?
    public var turn = 0

    public init(setups: [PlayerSetup], rules: Rules, seed: UInt32, presetDeck: [Int]? = nil) {
        precondition(setups.count == seats, "players must be \(seats)")
        self.rules = rules
        self.players = setups.map { PlayerState(setup: $0) }
        self.rng = Mulberry32(seed: seed)
        self.presetDeck = presetDeck
        dealRound()
    }

    private mutating func buildDeck() -> [Tile] {
        let tiles = makeTiles()
        if let preset = presetDeck, round == 0 {
            var pools = [[Tile]](repeating: [], count: numKinds)
            for t in tiles { pools[t.kind].append(t) }
            var deck: [Tile] = []
            for k in preset {
                guard !pools[k].isEmpty else { preconditionFailure("preset deck uses too many tiles of kind \(k)") }
                deck.append(pools[k].removeFirst())
            }
            precondition(deck.count == tiles.count, "preset deck must contain every tile")
            return deck
        }
        return rng.shuffle(tiles)
    }

    private mutating func dealRound() {
        var deck = buildDeck()
        for i in players.indices {
            players[i].hand = []
            players[i].discards = []
        }
        for i in 0..<seats {
            players[(dealer + i) % seats].hand = Array(deck.prefix(handSize))
            deck.removeFirst(handSize)
        }
        wall = deck
        current = dealer
        phase = .draw
        lastDiscard = nil
        claimQueue = []
        drawn = nil
        result = nil
        turn = 0
    }

    /// 1手進める。できない操作なら false を返して何も変えない
    @discardableResult
    public mutating func apply(_ action: Action) -> Bool {
        switch action {
        case .draw:
            guard phase == .draw else { return false }
            if wall.isEmpty {
                endRound(RoundResult(kind: .exhausted, winner: nil, from: nil, tile: nil, win: nil, deltas: [0, 0, 0, 0]))
                return true
            }
            let tile = wall.removeFirst()
            players[current].hand.append(tile)
            drawn = tile
            phase = .discard
            turn += 1
            return true

        case .tsumo:
            guard phase == .discard, let win = scoreWin(players[current].hand, tsumo: true) else { return false }
            var deltas = [0, 0, 0, 0]
            deltas[current] = win.total
            endRound(RoundResult(kind: .tsumo, winner: current, from: nil, tile: drawn, win: win, deltas: deltas))
            return true

        case let .discard(tileId):
            guard phase == .discard, let idx = players[current].hand.firstIndex(where: { $0.id == tileId }) else { return false }
            let tile = players[current].hand.remove(at: idx)
            players[current].discards.append(tile)
            lastDiscard = Discard(tile: tile, from: current)
            drawn = nil
            claimQueue = []
            for i in 1..<seats {
                let q = (current + i) % seats
                if canWin(players[q].hand, with: tile) { claimQueue.append(q) }
            }
            if claimQueue.isEmpty { advance() } else { phase = .claim }
            return true

        case let .ron(player):
            guard phase == .claim, claimQueue.first == player, let ld = lastDiscard else { return false }
            let hand = players[player].hand + [ld.tile]
            guard let win = scoreWin(hand, tsumo: false) else { return false }
            players[ld.from].discards.removeAll { $0.id == ld.tile.id }
            players[player].hand = hand
            var deltas = [0, 0, 0, 0]
            deltas[player] += win.total
            deltas[ld.from] -= rules.furikomiPenalty
            endRound(RoundResult(kind: .ron, winner: player, from: ld.from, tile: ld.tile, win: win, deltas: deltas))
            return true

        case let .pass(player):
            guard phase == .claim, claimQueue.first == player else { return false }
            claimQueue.removeFirst()
            if claimQueue.isEmpty { advance() }
            return true

        case .nextRound:
            guard phase == .roundEnd else { return false }
            round += 1
            if round >= rules.rounds {
                phase = .matchEnd
                return true
            }
            dealer = round % seats
            dealRound()
            return true
        }
    }

    public func applying(_ action: Action) -> GameState? {
        var s = self
        return s.apply(action) ? s : nil
    }

    private mutating func advance() {
        claimQueue = []
        current = (current + 1) % seats
        phase = .draw
    }

    private mutating func endRound(_ r: RoundResult) {
        for (i, d) in r.deltas.enumerated() { players[i].score += d }
        result = r
        history.append(r)
        phase = .roundEnd
    }

    /// 順位（同点なら人間が上、その次は席順）
    public var standings: [Int] {
        (0..<seats).sorted { a, b in
            let pa = players[a], pb = players[b]
            if pa.score != pb.score { return pa.score > pb.score }
            if pa.isHuman != pb.isHuman { return pa.isHuman }
            return a < b
        }
    }

    public func place(of seat: Int) -> Int {
        standings.firstIndex(of: seat) ?? 3
    }
}

public func canWin(_ hand: [Tile], with extra: Tile? = nil) -> Bool {
    var counts = countKinds(hand)
    if let e = extra { counts[e.kind] += 1 }
    return isWinningHand(counts)
}
