// 広告を「いつ出してよいか」の決まり。広告SDKには依存しない（AdMob などは iOS アプリ側の AdService で差し替える）。
//
// ・練習中・対局中・最初の3試合は出さない
// ・全画面広告は「試合が終わってタイトルに戻るとき」だけ。2試合に1回まで、3分以上あける
// ・リワード広告（見た人だけ★+1）は1日3回まで

import Foundation

public struct AdPolicy: Codable, Sendable, Equatable {
    public var matchesFinished = 0
    public var matchesSinceInterstitial = 0
    public var lastInterstitial: Date?
    public var rewardDay = ""
    public var rewardsToday = 0

    public static let freeMatches = 3
    public static let interstitialEvery = 2
    public static let interstitialGap: TimeInterval = 180
    public static let rewardsPerDay = 3

    public init() {}

    public mutating func recordMatchFinished() {
        matchesFinished += 1
        matchesSinceInterstitial += 1
    }

    public func canShowInterstitial(now: Date = Date()) -> Bool {
        guard matchesFinished > Self.freeMatches, matchesSinceInterstitial >= Self.interstitialEvery else { return false }
        if let last = lastInterstitial, now.timeIntervalSince(last) < Self.interstitialGap { return false }
        return true
    }

    public mutating func recordInterstitial(now: Date = Date()) {
        lastInterstitial = now
        matchesSinceInterstitial = 0
    }

    public func canOfferReward(now: Date = Date()) -> Bool {
        guard matchesFinished >= Self.freeMatches else { return false }
        return (Self.dayKey(now) == rewardDay ? rewardsToday : 0) < Self.rewardsPerDay
    }

    public func rewardsLeft(now: Date = Date()) -> Int {
        Self.rewardsPerDay - (Self.dayKey(now) == rewardDay ? rewardsToday : 0)
    }

    public mutating func recordReward(now: Date = Date()) {
        let key = Self.dayKey(now)
        if key != rewardDay {
            rewardDay = key
            rewardsToday = 0
        }
        rewardsToday += 1
    }

    static func dayKey(_ date: Date) -> String {
        let c = Calendar(identifier: .gregorian).dateComponents(in: TimeZone.current, from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }
}
