// 設定 →「広告《こうこく》とプライバシー」：年齢・追跡の許可・広告のプライバシー設定（欧州など）・プライバシーポリシー

import SwiftUI
import UIKit

struct PrivacySettingsView: View {
    @ObservedObject private var privacy = AdPrivacy.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RubyText("広告《こうこく》とプライバシー", size: 22, display: true)
                    HStack {
                        Spacer()
                        IconButton(icon: .close, label: "閉じる") { dismiss() }
                    }
                }
                .padding(.bottom, 4)

                RubyText("年齢《ねんれい》", size: 15, bold: true)
                HStack(spacing: 6) {
                    ageChoice("13歳《さい》以上《いじょう》", adult: true)
                    ageChoice("12歳《さい》以下《いか》", adult: false)
                }
                RubyText(privacy.choices.isAdult == false
                         ? "子《こ》ども向《む》けの広告《こうこく》だけが出《で》るよ。あなたに合《あ》わせた広告《こうこく》は出《で》ないよ。"
                         : "12歳《さい》以下《いか》にすると、子《こ》ども向《む》けの広告《こうこく》だけになるよ。",
                         size: 12, color: Palette.inkSoft)

                if privacy.choices.isAdult == true && AdConfig.enabled {
                    RubyText("追跡《ついせき》の許可《きょか》", size: 15, bold: true)
                        .padding(.top, 4)
                    row(title: trackingTitle, note: "あなたに合《あ》わせた広告《こうこく》を出《だ》すために使《つか》うよ。iPhoneの設定《せってい》でいつでも変《か》えられるよ。") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }

                if privacy.privacyOptionsRequired {
                    row(title: "広告《こうこく》のプライバシー設定《せってい》", note: "広告《こうこく》についての同意《どうい》をやり直《なお》す") {
                        Task { await privacy.presentPrivacyOptions() }
                    }
                }

                row(title: "プライバシーポリシー", note: "集《あつ》める情報《じょうほう》と使《つか》い方《かた》（ブラウザで開《ひら》く）") {
                    openURL(PrivacyLinks.policy)
                }
                .padding(.top, 4)
            }
            .padding(20)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.bg.ignoresSafeArea())
    }

    private var trackingTitle: String {
        switch privacy.tracking {
        case .allowed: return "許可《きょか》している"
        case .denied: return "許可《きょか》していない"
        case .restricted: return "この端末《たんまつ》では使《つか》えない"
        case .notAsked: return "まだ聞《き》いていない"
        }
    }

    private func ageChoice(_ label: String, adult: Bool) -> some View {
        let on = privacy.choices.isAdult == adult
        return Button {
            guard !on else { return }
            Task { await privacy.setAge(adult: adult) }
        } label: {
            RubyText(label, size: 14, bold: true, color: on ? Palette.onPink : Palette.ink)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(on ? Palette.pink : Palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(on ? Palette.pink : Palette.line, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(plainText(label))
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func row(title: String, note: String, action: @escaping () -> Void) -> some View {
        PrivacyLinkRow(title: title, note: note, action: action)
    }
}

/// 押すと別の画面へ進む行（設定の「広告とプライバシー」の入口でも使う）
struct PrivacyLinkRow: View {
    let title: String
    let note: String
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    RubyText(title, size: 16, bold: true)
                    RubyText(note, size: 12, color: Palette.inkSoft)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Palette.inkSoft)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(Palette.surface))
            .overlay(shape.strokeBorder(Palette.line, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(plainText(title))
    }
}
