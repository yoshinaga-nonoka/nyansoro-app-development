// 広告の受け皿。いつ出すかは NyansoroCore/AdPolicy.swift、どう出すかはここ。
//
// いまは「テスト表示」だけ（開発用ビルドで、本物の広告の代わりに数秒のダミー画面を出す）。
// AdMob を入れるときは AdService に合う AdMobAdService を作り、AppModel.makeAdService() で差し替える。
// 手順は README.md の「広告（AdMob）を入れる」を参照。

import SwiftUI

@MainActor
protocol AdService: AnyObject {
    /// 動画を最後まで見たら true（ごほうびを渡してよい）
    func showRewarded() async -> Bool
    func showInterstitial() async
}

/// 開発用：本物の広告の代わりに、数秒のダミー画面を出す
@MainActor
final class DebugAdService: ObservableObject, AdService {
    struct Showing: Identifiable {
        let id = UUID()
        let rewarded: Bool
        let seconds: Int
    }

    @Published private(set) var showing: Showing?
    private var continuation: CheckedContinuation<Bool, Never>?

    func showRewarded() async -> Bool {
        await present(rewarded: true, seconds: 5)
    }

    func showInterstitial() async {
        _ = await present(rewarded: false, seconds: 3)
    }

    private func present(rewarded: Bool, seconds: Int) async -> Bool {
        await withCheckedContinuation { cont in
            continuation?.resume(returning: false)
            continuation = cont
            showing = Showing(rewarded: rewarded, seconds: seconds)
        }
    }

    func finish(completed: Bool) {
        showing = nil
        continuation?.resume(returning: completed)
        continuation = nil
    }
}

/// ダミー広告の画面
struct DebugAdOverlay: View {
    @ObservedObject var ads: DebugAdService
    @State private var remaining = 0

    var body: some View {
        if let ad = ads.showing {
            ZStack {
                Color.black.opacity(0.88).ignoresSafeArea()
                VStack(spacing: 16) {
                    Text(ad.rewarded ? "動画広告（テスト表示）" : "広告（テスト表示）")
                        .font(AppFont.display(20))
                        .foregroundColor(.white)
                    Text("ここに AdMob の広告が出ます")
                        .font(AppFont.body(14))
                        .foregroundColor(.white.opacity(0.8))
                    if remaining > 0 {
                        Text("あと \(remaining) 秒")
                            .font(AppFont.body(16, bold: true))
                            .foregroundColor(.white)
                    }
                    HStack(spacing: 12) {
                        if ad.rewarded && remaining > 0 {
                            Button("やめる") { ads.finish(completed: false) }
                                .buttonStyle(PillButtonStyle(kind: .ghost))
                        }
                        if remaining == 0 {
                            Button(ad.rewarded ? "ごほうびをもらう" : "閉じる") { ads.finish(completed: true) }
                                .buttonStyle(PillButtonStyle(kind: .primary))
                        }
                    }
                }
                .padding(24)
            }
            .task(id: ad.id) {
                remaining = ad.seconds
                while remaining > 0 {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    if Task.isCancelled { return }
                    remaining -= 1
                }
            }
        }
    }
}
