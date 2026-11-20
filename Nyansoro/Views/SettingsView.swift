// 設定：ヒント・ふりがな・自動でにゃん！・音・振動・CPUの速さ・マット・アカウント・データの消去

import AuthenticationServices
import SwiftUI

struct SettingsView: View {
    @ObservedObject var app: AppModel
    var allowReset = true
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false
    @ObservedObject private var privacy = AdPrivacy.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RubyText("設定《せってい》", size: 22, display: true)
                    HStack {
                        Spacer()
                        IconButton(icon: .close, label: "閉じる") { dismiss() }
                    }
                }
                .padding(.bottom, 4)

                ToggleRow(title: "ヒント", note: "おすすめマーク・セットの線《せん》・あと何枚《なんまい》", isOn: $app.save.settings.hints)
                ToggleRow(title: "ふりがな", note: "漢字《かんじ》に読《よ》み方《かた》を付《つ》ける", isOn: $app.save.settings.furigana)
                ToggleRow(title: "自動《じどう》でにゃん！", note: "揃《そろ》ったら自動《じどう》で上《あ》がる（見逃《みのが》さない）", isOn: $app.save.settings.autoNyan)
                ToggleRow(title: "毎日《まいにち》のお知《し》らせ", note: "19時《じ》に「今日《きょう》の1局《きょく》」をお知《し》らせ（遊《あそ》んだ日《ひ》は出《で》ない）", isOn: remindersBinding)
                ToggleRow(title: "音《おと》", note: "効果音《こうかおん》", isOn: $app.save.settings.sound)
                ToggleRow(title: "振動《しんどう》", note: "タップや上《あ》がりのときに少《すこ》し震《ふる》える", isOn: $app.save.settings.haptics)

                RubyText("CPUの速《はや》さ", size: 15, bold: true)
                    .padding(.top, 4)
                HStack(spacing: 6) {
                    ForEach(Speed.allCases, id: \.self) { s in
                        let on = app.save.settings.speed == s
                        Button { app.save.settings.speed = s } label: {
                            RubyText(s.label, size: 14, bold: true, color: on ? Palette.onPink : Palette.ink)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(on ? Palette.pink : Palette.surface))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(on ? Palette.pink : Palette.line, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(plainText(s.label))
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }

                RubyText("テーブルマット", size: 15, bold: true)
                    .padding(.top, 4)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                    ForEach(MatId.allCases, id: \.self) { m in
                        matSwatch(m)
                    }
                }

                PrivacyLinkRow(title: "広告《こうこく》とプライバシー", note: "年齢《ねんれい》・追跡《ついせき》の許可《きょか》・プライバシーポリシー") { AdPrivacy.shared.showSettings = true }
                    .padding(.top, 8)

                if allowReset && AccountConfig.enabled {
                    accountArea
                        .padding(.top, 12)
                }

                if allowReset {
                    resetArea
                        .padding(.top, 12)
                }
            }
            .padding(20)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.bg.ignoresSafeArea())
        .sheet(isPresented: $privacy.showSettings) {
            PrivacySettingsView()
                .environment(\.furigana, app.settings.furigana)
        }
    }

    @Environment(\.colorScheme) private var colorScheme
    @State private var signInFailed = false

    /// Apple でサインイン（有料登録のあと AccountConfig.signInEnabled を true にすると出る）
    private var accountArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            RubyText("アカウント", size: 15, bold: true)
            if let acc = app.account {
                RubyText("Apple でサインイン中《ちゅう》\(acc.name.map { "：\($0)" } ?? "")", size: 14)
                RubyText(CloudSave.enabled ? "記録《きろく》は iCloud にも保存《ほぞん》されるよ。" : "記録《きろく》はこの端末《たんまつ》に保存《ほぞん》されるよ。", size: 12, color: Palette.inkSoft)
                Button { app.signOut() } label: {
                    RubyText("サインアウト", size: 15, display: true)
                }
                .buttonStyle(PillButtonStyle(kind: .ghost))
            } else {
                RubyText("サインインすると、記録《きろく》がアカウントに貯《た》まっていく。しなくても全部《ぜんぶ》遊《あそ》べるよ。", size: 12, color: Palette.inkSoft)
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    let r = AppleSignIn.account(from: result)
                    if let acc = r.account { app.signedIn(acc) }
                    signInFailed = r.failed
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 46)
                .frame(maxWidth: 380)
                if signInFailed {
                    RubyText("サインインできなかったよ。時間《じかん》をおいて試《ため》してね。", size: 12, color: Palette.bad)
                }
            }
        }
    }

    /// オンにしたときは通知の許可を聞く
    private var remindersBinding: Binding<Bool> {
        Binding(
            get: { app.save.settings.reminders },
            set: { on in
                if on {
                    app.enableReminders()
                } else {
                    app.save.settings.reminders = false
                    app.refreshReminders()
                }
            }
        )
    }

    private func matSwatch(_ m: MatId) -> some View {
        let unlocked = app.unlockedMats.contains(m)
        let on = app.save.settings.mat == m
        let unlockRank = Ranks.all.first { $0.mat == m }?.name ?? ""
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return Button { app.save.settings.mat = m } label: {
            VStack(alignment: .leading, spacing: 2) {
                Spacer(minLength: 0)
                RubyText(m.name, size: 14, bold: true, color: Palette.matInk)
                if !unlocked {
                    RubyText("\(unlockRank)ランクで", size: 11, color: Palette.matInkSoft)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
            .background(shape.fill(m.style.fill))
            .overlay(shape.strokeBorder(on ? Palette.pinkPress : m.style.edge, lineWidth: on ? 3 : 2))
            .opacity(unlocked ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
        .accessibilityLabel(plainText(m.name) + (unlocked ? "" : "（まだ使えない）"))
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    @ViewBuilder
    private var resetArea: some View {
        if confirmReset {
            VStack(spacing: 10) {
                RubyText("ランクと★が全部《ぜんぶ》消《き》えるよ。本当《ほんとう》に？", size: 14, alignment: .center)
                HStack(spacing: 10) {
                    Button { confirmReset = false } label: { RubyText("やめる", size: 15, display: true) }
                        .buttonStyle(PillButtonStyle(kind: .ghost))
                    Button {
                        app.resetData()
                        confirmReset = false
                    } label: {
                        RubyText("消《け》す", size: 15, display: true, color: Palette.surface)
                    }
                    .buttonStyle(PillButtonStyle(kind: .danger))
                }
            }
            .frame(maxWidth: .infinity)
        } else {
            Button { confirmReset = true } label: {
                RubyText("データを最初《さいしょ》からにする", size: 13, color: Palette.inkSoft)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        }
    }
}

struct ToggleRow: View {
    let title: String
    let note: String
    @Binding var isOn: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                RubyText(title, size: 16, bold: true)
                RubyText(note, size: 12, color: Palette.inkSoft)
            }
        }
        .tint(Palette.mintPress)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(shape.fill(Palette.surface))
        .overlay(shape.strokeBorder(Palette.line, lineWidth: 2))
        .accessibilityLabel(plainText(title))
    }
}
