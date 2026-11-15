// 広告のプライバシー：年齢の確認（13歳以上か）、欧州などの同意（Google UMP）、追跡の許可（ATT）。
//
// 流れ（起動のたび。聞くのはまだ答えていないことだけ）
//   1. 年齢を聞く（初回だけ。画面は Privacy/PrivacyGate.swift）
//   2. 同意情報を更新し、欧州などで必要なら Google の同意画面を出す
//   3. 13歳以上の人にだけ、追跡の許可を1回だけ聞く（13歳未満には出さない）
//   4. ここまで済んだら広告を読み込んでよい（AdMobAdService は waitUntilReady() を待つ）
// 13歳未満は「子ども向け扱い」（ageRestrictedTreatment = .child。旧 tagForChildDirectedTreatment）で広告を読み込む。
// 答えは端末に保存（ゲームのセーブとは別のキー。「データを最初からにする」でも消えない）。設定から変えられる。

import SwiftUI
import UIKit
#if canImport(AppTrackingTransparency)
import AppTrackingTransparency
#endif
#if canImport(UserMessagingPlatform)
import UserMessagingPlatform
#endif
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

struct PrivacyChoices: Codable, Equatable {
    /// 13歳以上か（nil = まだ聞いていない）
    var isAdult: Bool?
    /// 追跡の許可をもう聞いたか
    var askedTracking = false
}

enum PrivacyLinks {
    /// プライバシーポリシーのページ（docs/privacy-policy.md を公開した場所）
    static let policy = URL(string: "https://yoshinaga-nonoka.github.io/nyansoro/privacy-policy.html")!
}

@MainActor
final class AdPrivacy: ObservableObject {
    static let shared = AdPrivacy()

    enum Tracking {
        case notAsked, allowed, denied, restricted
    }

    @Published private(set) var choices: PrivacyChoices
    /// 広告を読み込んでよい状態か（同意の確認まで済んだ）
    @Published private(set) var ready = false
    /// 欧州などで「広告のプライバシー設定」（同意のやり直し）の入口が必要か
    @Published private(set) var privacyOptionsRequired = false
    /// 年齢を変えたら増える（先読みした広告を捨てて、新しい扱いで読み込み直すため）
    @Published private(set) var revision = 0
    /// 「広告とプライバシー」画面を開いているか
    @Published var showSettings = false

    private static let key = "nyansoro.privacy.v1"
    private let persist: Bool
    private var preparing = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    #if DEBUG
    /// 開発用：同意画面を「欧州にいる」として確かめる（-scenario consent-eea）
    private var debugEEA = false
    #endif

    var needsAgeQuestion: Bool { choices.isAdult == nil }

    private init() {
        var loaded = PrivacyChoices()
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(PrivacyChoices.self, from: data) {
            loaded = saved
        }
        var persist = true
        #if DEBUG
        // 画面の自動撮影（-scenario）では保存せず、場面に合わせた状態から始める
        if let scenario = Self.debugScenarioName {
            persist = false
            switch scenario {
            case "age-check":
                loaded = PrivacyChoices()
            case "att-prompt":
                loaded = PrivacyChoices(isAdult: true, askedTracking: false)
            case "consent-eea":
                loaded = PrivacyChoices(isAdult: true, askedTracking: true)
                debugEEA = true
            case "privacy-child":
                loaded = PrivacyChoices(isAdult: false, askedTracking: false)
            default:
                loaded = PrivacyChoices(isAdult: true, askedTracking: true)
            }
        }
        #endif
        self.persist = persist
        self.choices = loaded
    }

    #if DEBUG
    static var debugScenarioName: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-scenario"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
    #endif

    // MARK: 年齢

    /// 年齢の答え（初回の確認でも、設定から変えたときも）
    func setAge(adult: Bool) async {
        let changed = choices.isAdult != nil && choices.isAdult != adult
        choices.isAdult = adult
        save()
        applyAgeToAds()
        if changed {
            revision += 1
            // 13歳以上 ↔ 未満が変わったら、同意情報もその扱いで更新する（同意画面はここでは出さない）
            await updateConsent(presentForm: false)
            if adult { await askTrackingIfNeeded() }
        } else {
            await prepare()
        }
    }

    // MARK: 準備（起動のたび）

    /// 年齢が分かっていれば、同意の確認 → 追跡の許可 の順に進めて、広告の準備を整える
    func prepare() async {
        guard !ready, !preparing, choices.isAdult != nil else { return }
        preparing = true
        defer { preparing = false }
        applyAgeToAds()
        if AdConfig.enabled {
            await updateConsent(presentForm: true)
            await askTrackingIfNeeded()
        }
        ready = true
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }

    /// 広告を読み込む前に待つ
    func waitUntilReady() async {
        if ready { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    /// 広告を読み込んでよいか（欧州などで同意がまだなら false）
    var canRequestAds: Bool {
        guard ready else { return false }
        #if canImport(UserMessagingPlatform)
        return ConsentInformation.shared.canRequestAds
        #else
        return true
        #endif
    }

    private func applyAgeToAds() {
        #if canImport(GoogleMobileAds)
        let config = MobileAds.shared.requestConfiguration
        // 子どもも遊ぶので、広告の内容は「保護者の指導があれば見てよい」まで
        config.maxAdContentRating = .parentalGuidance
        config.ageRestrictedTreatment = choices.isAdult == false ? .child : .unspecified
        #endif
    }

    // MARK: 欧州などの同意（Google User Messaging Platform）

    private func updateConsent(presentForm: Bool) async {
        #if canImport(UserMessagingPlatform)
        let params = RequestParameters()
        // 13歳未満は「同意できる年齢に満たない」扱い（同意画面は出ず、個人に合わせた広告も出ない）
        params.isTaggedForUnderAgeOfConsent = choices.isAdult == false
        #if DEBUG
        if debugEEA {
            let debug = DebugSettings()
            debug.geography = .EEA  // シミュレーターは自動で「テスト端末」扱い
            params.debugSettings = debug
        }
        #endif
        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: params)
            if presentForm, choices.isAdult == true {
                try await ConsentForm.loadAndPresentIfRequired(from: UIApplication.topViewController())
            }
        } catch {
            // 通信できないときなど。前回の同意が残っていればそれで広告を出す（canRequestAds）
            print("[AdPrivacy] 同意情報の更新に失敗: \(error.localizedDescription)")
        }
        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        #endif
    }

    /// 「広告のプライバシー設定」：同意をやり直す画面を出す
    func presentPrivacyOptions() async {
        #if canImport(UserMessagingPlatform)
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: UIApplication.topViewController())
        } catch {
            print("[AdPrivacy] プライバシー設定の画面を出せなかった: \(error.localizedDescription)")
        }
        revision += 1
        #endif
    }

    // MARK: 追跡の許可（App Tracking Transparency）

    var tracking: Tracking {
        #if canImport(AppTrackingTransparency)
        switch ATTrackingManager.trackingAuthorizationStatus {
        case .authorized: return .allowed
        case .denied: return .denied
        case .restricted: return .restricted
        default: return .notAsked
        }
        #else
        return .restricted
        #endif
    }

    /// 13歳以上で、まだ聞いていなければ1回だけ聞く
    private func askTrackingIfNeeded() async {
        #if canImport(AppTrackingTransparency)
        guard choices.isAdult == true, AdConfig.enabled, !choices.askedTracking else { return }
        guard tracking == .notAsked else {
            choices.askedTracking = true  // 入れ直したときなど、もう答えてある
            save()
            return
        }
        // アプリが前に出ているときでないと確認が出ないので、少し待つ
        for _ in 0..<20 where UIApplication.shared.applicationState != .active {
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        _ = await ATTrackingManager.requestTrackingAuthorization()
        if tracking != .notAsked {
            choices.askedTracking = true
            save()
        }
        #endif
    }

    private func save() {
        guard persist, let data = try? JSONEncoder().encode(choices) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}

extension UIApplication {
    /// いちばん上に出ている画面（広告や同意画面を重ねて出す先）
    static func topViewController() -> UIViewController? {
        let scene = shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
