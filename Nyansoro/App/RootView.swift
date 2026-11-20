// 画面の切り替え（タイトル・ランク選択・対戦）と、共通のシート・広告の表示

import SwiftUI

struct RootView: View {
    @EnvironmentObject var app: AppModel

    var body: some View {
        ZStack {
            switch app.screen {
            case .title:
                TitleView(app: app)
                    .transition(.opacity)
            case .ranks:
                RankSelectView(app: app)
                    .transition(.opacity)
            case let .game(mode, id):
                GameView(mode: mode, app: app)
                    .id(id)
                    .transition(.opacity)
            }

            if app.showOnline {
                ModalCard(maxWidth: 440) {
                    RubyText("オンライン対戦《たいせん》は準備中《じゅんびちゅう》", size: 20, display: true, alignment: .center)
                    RubyText("次《つぎ》のバージョンで遊《あそ》べるようにするよ。", size: 14, alignment: .center)
                    VStack(alignment: .leading, spacing: 8) {
                        RubyText("**友達《ともだち》と：**4桁《けた》の「合言葉《あいことば》」で同《おな》じ部屋《へや》に入《はい》る。空《あ》いた席《せき》にはCPUが座《すわ》るよ。", size: 14)
                        RubyText("**誰《だれ》かと：**近《ちか》いランクの人《ひと》と対戦《たいせん》。チャットはなしで、スタンプだけ。", size: 14)
                    }
                    Button { app.showOnline = false } label: {
                        RubyText("分《わ》かった", size: 16, display: true, color: Palette.onPink)
                    }
                    .buttonStyle(PillButtonStyle(kind: .primary))
                }
            }

            DebugAdOverlay(ads: app.debugAds)
            PrivacyGate()  // 初回の年齢確認と広告の準備（Privacy/）
        }
        .environment(\.furigana, app.settings.furigana)
        .sheet(isPresented: $app.showHelp) {
            HelpView(game: nil)
                .environment(\.furigana, app.settings.furigana)
        }
        .sheet(isPresented: $app.showLesson) {
            LessonView()
                .environmentObject(app)
                .environment(\.furigana, app.settings.furigana)
        }
        .sheet(isPresented: $app.showMissions) {
            MissionsView()
                .environmentObject(app)
                .environment(\.furigana, app.settings.furigana)
        }
        .sheet(isPresented: $app.showSettings) {
            SettingsView(app: app)
                .environment(\.furigana, app.settings.furigana)
        }
    }
}
