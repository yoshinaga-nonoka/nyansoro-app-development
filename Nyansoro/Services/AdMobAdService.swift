// AdMob（Google Mobile Ads SDK）で広告を出す。いつ出すかの決まりは NyansoroCore/AdPolicy.swift。

#if canImport(GoogleMobileAds)
import GoogleMobileAds
import UIKit

@MainActor
final class AdMobAdService: NSObject, AdService, FullScreenContentDelegate {
    private var rewarded: RewardedAd?
    private var interstitial: InterstitialAd?
    private var dismissed: CheckedContinuation<Void, Never>?
    private var earnedReward = false

    override init() {
        super.init()
        // 子どもも遊ぶので、広告の内容は「保護者の指導があれば見てよい」まで
        MobileAds.shared.requestConfiguration.maxAdContentRating = .parentalGuidance
        MobileAds.shared.start(completionHandler: nil)
        Task { await preload() }
    }

    private func preload() async {
        if rewarded == nil, !AdConfig.rewardedUnitID.isEmpty {
            rewarded = try? await RewardedAd.load(with: AdConfig.rewardedUnitID, request: Request())
            rewarded?.fullScreenContentDelegate = self
        }
        if interstitial == nil, !AdConfig.interstitialUnitID.isEmpty {
            interstitial = try? await InterstitialAd.load(with: AdConfig.interstitialUnitID, request: Request())
            interstitial?.fullScreenContentDelegate = self
        }
    }

    func showRewarded() async -> Bool {
        if rewarded == nil { await preload() }
        guard let ad = rewarded, let root = Self.topViewController() else { return false }
        rewarded = nil
        earnedReward = false
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            dismissed = cont
            ad.present(from: root) { [weak self] in
                self?.earnedReward = true
            }
        }
        Task { await preload() }
        return earnedReward
    }

    func showInterstitial() async {
        guard let ad = interstitial, let root = Self.topViewController() else {
            Task { await preload() }
            return
        }
        interstitial = nil
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            dismissed = cont
            ad.present(from: root)
        }
        Task { await preload() }
    }

    // 広告を閉じたとき・出せなかったとき
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in self.finish() }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in self.finish() }
    }

    private func finish() {
        dismissed?.resume()
        dismissed = nil
    }

    /// 広告を重ねて出す画面（いちばん上に出ている画面）
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
#endif
