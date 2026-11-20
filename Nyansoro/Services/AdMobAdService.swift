// AdMob（Google Mobile Ads SDK）で広告を出す。いつ出すかの決まりは NyansoroCore/AdPolicy.swift。
// 年齢・同意・追跡の許可（Services/AdPrivacy.swift）が済むまでは、広告を読み込まない。

#if canImport(GoogleMobileAds)
import GoogleMobileAds
import UIKit

@MainActor
final class AdMobAdService: NSObject, AdService, FullScreenContentDelegate {
    private var rewarded: RewardedAd?
    private var interstitial: InterstitialAd?
    private var dismissed: CheckedContinuation<Void, Never>?
    private var earnedReward = false
    private var started = false
    /// 先読みした広告が、どの年齢・同意の扱いで読み込んだものか（AdPrivacy.revision）
    private var loadedRevision = 0

    override init() {
        super.init()
        Task { await preload() }
    }

    private func preload() async {
        let privacy = AdPrivacy.shared
        await privacy.waitUntilReady()
        guard privacy.canRequestAds else { return }
        if !started {
            started = true
            MobileAds.shared.start(completionHandler: nil)
        }
        // 年齢や同意を変えたら、前の扱いで読み込んだ広告は使わない
        if loadedRevision != privacy.revision {
            loadedRevision = privacy.revision
            rewarded = nil
            interstitial = nil
        }
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
        await preload()
        guard let ad = rewarded, let root = UIApplication.topViewController() else { return false }
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
        if loadedRevision != AdPrivacy.shared.revision { await preload() }
        guard let ad = interstitial, let root = UIApplication.topViewController() else {
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
}
#endif
