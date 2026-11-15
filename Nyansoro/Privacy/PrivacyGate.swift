// 初回起動の年齢確認（「13歳以上ですか？」だけ。生年月日は聞かない）と、起動のたびの広告の準備。
// RootView のいちばん上に重ねて置く。答えたあとの流れは Services/AdPrivacy.swift。

import SwiftUI

struct PrivacyGate: View {
    @EnvironmentObject var app: AppModel
    @ObservedObject private var privacy = AdPrivacy.shared
    @State private var answering = false

    var body: some View {
        ZStack {
            if privacy.needsAgeQuestion {
                ModalCard(maxWidth: 440) {
                    RubyText("はじめに教《おし》えてね", size: 20, display: true, alignment: .center)
                    RubyText("あなたは**13歳《さい》以上《いじょう》**ですか？", size: 17, alignment: .center)
                    RubyText("広告《こうこく》の出《だ》し方《かた》を決《き》めるためだけに使《つか》うよ。生年月日《せいねんがっぴ》は聞《き》かないよ。あとで設定《せってい》から変《か》えられるよ。", size: 13, color: Palette.inkSoft, alignment: .center)
                    VStack(spacing: 10) {
                        answerButton("はい（13歳《さい》以上《いじょう》）", adult: true)
                        answerButton("いいえ（12歳《さい》以下《いか》）", adult: false)
                    }
                }
            }
        }
        .task {
            await privacy.prepare()
            #if DEBUG
            if AdPrivacy.debugScenarioName?.hasPrefix("privacy") == true {
                app.showSettings = true
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                privacy.showSettings = true
            }
            #endif
        }
    }

    /// どちらの答えも同じ見た目（どちらかに誘導しない）
    private func answerButton(_ label: String, adult: Bool) -> some View {
        Button {
            guard !answering else { return }
            answering = true
            SoundPlayer.shared.tap()
            Task { await privacy.setAge(adult: adult) }
        } label: {
            RubyText(label, size: 16, display: true, color: Palette.onMint)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PillButtonStyle(kind: .secondary))
        .accessibilityLabel(plainText(label))
    }
}
