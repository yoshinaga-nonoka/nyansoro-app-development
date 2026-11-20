// 初めて起動したときの説明（ホーム画面の前に出す）。
// ① ようこそ（Apple でサインイン／あとで）② 勝ち方 ③ セット ④ パパ・ママ・子猫 ⑤ 招き猫 ⑥ 順番 ⑦ リーチと役 ⑧ 練習へ
// 「遊び方」からも見直せる（そのときは最後に閉じるだけ）。

import AuthenticationServices
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var app: AppModel
    /// 「遊び方」から見直しているとき
    var replay = false

    @State private var page = 0
    @State private var signInFailed = false
    @Environment(\.colorScheme) private var colorScheme

    init(app: AppModel, replay: Bool = false) {
        self.app = app
        self.replay = replay
        var first = 0
        #if DEBUG
        switch DebugScenario.current {
        case .onboardingRoles?: first = Page.roles.rawValue
        case .onboardingRiichi?: first = Page.riichi.rawValue
        default: break
        }
        #endif
        _page = State(initialValue: first)
    }

    private enum Page: Int, CaseIterable {
        case welcome, win, sets, roles, joker, turn, riichi, practice
    }

    private var pages: [Page] {
        // サインインを使わないとき（有料登録の前）は、ようこその次からすぐ説明
        Page.allCases
    }

    private var current: Page { pages[min(page, pages.count - 1)] }
    private var isLast: Bool { page >= pages.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(spacing: 16) {
                    content
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .id(page)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
            bottomBar
        }
        .background(Palette.bg.ignoresSafeArea())
    }

    // MARK: 上と下

    private var topBar: some View {
        HStack(spacing: 8) {
            if page > 0 {
                IconButton(icon: .back, label: "もどる") { go(page - 1) }
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                ForEach(0..<pages.count, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? Palette.pinkPress : i < page ? Palette.pink : Palette.lineStrong)
                        .frame(width: i == page ? 20 : 8, height: 8)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(page + 1) / \(pages.count) ページ")
            Spacer(minLength: 0)
            if replay {
                IconButton(icon: .close, label: "閉じる") { app.showIntro = false }
            } else if page > 0, !isLast {
                Button { go(pages.count - 1) } label: {
                    RubyText("飛《と》ばす", size: 13, bold: true, color: Palette.inkSoft)
                }
                .frame(minWidth: 44, minHeight: 44)
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: 8) {
            switch current {
            case .welcome:
                if AccountConfig.enabled && !replay && app.account == nil {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        let r = AppleSignIn.account(from: result)
                        if let acc = r.account {
                            app.signedIn(acc)
                            go(1)
                        } else if r.failed {
                            signInFailed = true
                        }
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 50)
                    .frame(maxWidth: 380)
                    Button {
                        app.save.onboarding.signInOffered = true
                        go(1)
                    } label: {
                        RubyText("あとで（サインインせずに遊《あそ》ぶ）", size: 15, display: true)
                            .frame(maxWidth: 380)
                    }
                    .buttonStyle(PillButtonStyle(kind: .ghost))
                } else {
                    nextButton("はじめる")
                }
            case .practice:
                if replay {
                    Button { app.showIntro = false } label: {
                        RubyText("閉《と》じる", size: 17, display: true, color: Palette.onPink)
                            .frame(maxWidth: 380)
                    }
                    .buttonStyle(PillButtonStyle(kind: .primary))
                } else {
                    Button { app.finishIntro(start: .basics) } label: {
                        RubyText("練習《れんしゅう》をはじめる", size: 18, display: true, color: Palette.onGold)
                            .frame(maxWidth: 380)
                    }
                    .buttonStyle(PillButtonStyle(kind: .nyan))
                    Button { app.finishIntro(start: nil) } label: {
                        RubyText("あとで（ホームへ）", size: 14, display: true)
                    }
                    .buttonStyle(PillButtonStyle(kind: .ghost))
                }
            default:
                nextButton("次《つぎ》へ")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func nextButton(_ title: String) -> some View {
        Button { go(page + 1) } label: {
            RubyText(title, size: 17, display: true, color: Palette.onPink)
                .frame(maxWidth: 380)
        }
        .buttonStyle(PillButtonStyle(kind: .primary))
    }

    private func go(_ p: Int) {
        SoundPlayer.shared.tap()
        withAnimation(.easeOut(duration: 0.25)) { page = max(0, min(pages.count - 1, p)) }
    }

    // MARK: ページ

    @ViewBuilder
    private var content: some View {
        switch current {
        case .welcome: welcome
        case .win: win
        case .sets: sets
        case .roles: roles
        case .joker: jokerPage
        case .turn: turn
        case .riichi: riichi
        case .practice: practice
        }
    }

    private var welcome: some View {
        VStack(spacing: 16) {
            HeroTiles().padding(.top, 20)
            LogoView(size: 56)
            RubyText("ようこそ！", size: 26, display: true, alignment: .center)
            RubyText("猫《ねこ》の絵柄《えがら》を**3枚《まい》ずつ**揃《そろ》える、かんたんなゲームだよ。はじめに遊《あそ》び方《かた》を説明《せつめい》するね。", size: 15, alignment: .center)
            if AccountConfig.enabled && !replay {
                if let acc = app.account {
                    card {
                        RubyText("**サインインしたよ**\(acc.name.map { "：\($0)" } ?? "")", size: 14)
                    }
                } else {
                    card {
                        RubyText("Apple でサインインすると", size: 14, bold: true)
                        bullet("ランク・★・称号《しょうごう》などの記録《きろく》が、アカウントに貯《た》まっていく")
                        bullet("機種変更《きしゅへんこう》しても、同《おな》じ Apple ID なら続《つづ》きから遊《あそ》べる")
                        RubyText("サインインしなくても、全部《ぜんぶ》遊《あそ》べるよ。あとから「設定《せってい》」でもできる。", size: 12, color: Palette.inkSoft)
                    }
                }
                if signInFailed {
                    RubyText("サインインできなかったよ。「あとで」を押《お》して、設定《せってい》からもう一度《いちど》試《ため》してね。", size: 13, color: Palette.bad, alignment: .center)
                }
            }
        }
    }

    private var win: some View {
        VStack(spacing: 16) {
            title("勝《か》ち方《かた》")
            HStack(spacing: 14) {
                ForEach(Array([kindOf(0, 2), kindOf(2, 2), kindOf(3, 2), kindOf(5, 2)].enumerated()), id: \.offset) { item in
                    VStack(spacing: 4) {
                        Avatar(kind: item.element, size: 46)
                        RubyText(item.offset == 0 ? "キミ" : "CPU", size: 11, bold: true, color: Palette.inkSoft)
                    }
                }
            }
            RubyText("**4人《にん》**で遊《あそ》ぶよ。いちばん早《はや》く「**3枚《まい》セット**」を**3つ**作《つく》った人《ひと》の勝《か》ち！", size: 17, alignment: .center)
            HStack(spacing: 10) {
                exampleSet([kindOf(0, 0), kindOf(0, 0), kindOf(0, 0)])
                exampleSet([kindOf(1, 0), kindOf(1, 1), kindOf(1, 2)])
                exampleSet([kindOf(4, 2), kindOf(4, 2), kindOf(4, 2)])
            }
            RubyText("手持《ても》ちは8枚《まい》。自分《じぶん》の番《ばん》に1枚《まい》引《ひ》いて、9枚《まい》で3セットになったら「**にゃん！**」", size: 14, alignment: .center)
        }
    }

    private var sets: some View {
        VStack(spacing: 16) {
            title("セットは2種類《しゅるい》")
            card {
                RubyText("① 同《おな》じ猫《ねこ》を3枚《まい》", size: 16, bold: true)
                exampleSet([kindOf(3, 1), kindOf(3, 1), kindOf(3, 1)], width: 52)
                RubyText("まったく同《おな》じ絵柄《えがら》の猫《ねこ》を3枚《まい》。", size: 13, color: Palette.inkSoft)
            }
            card {
                RubyText("② 家族《かぞく》（パパ・ママ・子猫《こねこ》）", size: 16, bold: true)
                exampleSet([kindOf(4, 0), kindOf(4, 1), kindOf(4, 2)], width: 52)
                RubyText("同《おな》じ家族《かぞく》のパパ・ママ・子猫《こねこ》を1枚《まい》ずつ。", size: 13, color: Palette.inkSoft)
            }
            HStack(spacing: 10) {
                exampleSet([kindOf(0, 0), kindOf(1, 1), kindOf(2, 2)], width: 40)
                Text("×").font(AppFont.display(26)).foregroundColor(Palette.bad)
                RubyText("家族《かぞく》がバラバラだとセットにならない", size: 13, color: Palette.inkSoft)
            }
        }
    }

    private var roles: some View {
        VStack(spacing: 16) {
            title("パパ・ママ・子猫《こねこ》の見分《みわ》け方《かた》")
            HStack(alignment: .top, spacing: 14) {
                roleColumn(kindOf(2, 0), "パパ", "蝶《ちょう》ネクタイ")
                roleColumn(kindOf(2, 1), "ママ", "リボン")
                roleColumn(kindOf(2, 2), "子猫《こねこ》", "鈴《すず》")
            }
            RubyText("家族《かぞく》は6つ。**上《うえ》の帯《おび》の色《いろ》**と**毛《け》の模様《もよう》**が家族《かぞく》の印《しるし》だよ。", size: 14, alignment: .center)
            FlowLayout(alignment: .center) {
                ForEach(0..<numFamilies, id: \.self) { f in
                    VStack(spacing: 3) {
                        TileView(kind: kindOf(f, 0), width: 40)
                        RubyText(Catalog.families[f].name, size: 11, bold: true, color: FamilyColors.all[f].ink)
                            .padding(.horizontal, 8)
                            .background(Capsule().fill(FamilyColors.all[f].band))
                    }
                    .padding(4)
                }
            }
            RubyText("同《おな》じ猫《ねこ》は4枚《まい》ずつ。全部《ぜんぶ》で18種類《しゅるい》。", size: 13, color: Palette.inkSoft, alignment: .center)
        }
    }

    private var jokerPage: some View {
        VStack(spacing: 16) {
            title("招《まね》き猫《ねこ》")
            TileView(kind: joker, width: 74)
            RubyText("どの猫《ねこ》の代《か》わりにもなれる、すごい猫《ねこ》。全部《ぜんぶ》で2枚《まい》だけ。", size: 15, alignment: .center)
            exampleSet([kindOf(5, 0), joker, kindOf(5, 2)], width: 52)
            RubyText("ハチワレのママの代《か》わりに入《はい》って、家族《かぞく》セット！", size: 13, color: Palette.inkSoft, alignment: .center)
            RubyText("使《つか》わずに上《あ》がると +5点《てん》。", size: 13, color: Palette.inkSoft, alignment: .center)
        }
    }

    private var turn: some View {
        VStack(alignment: .leading, spacing: 14) {
            title("1回《かい》の番《ばん》でやること")
            step(1, "**引《ひ》く**：自分《じぶん》の番《ばん》になると、山《やま》から1枚《まい》引《ひ》く（自動《じどう》）")
            step(2, "**捨《す》てる**：いらない猫《ねこ》を2回《かい》タップして1枚《まい》捨《す》てる。迷《まよ》ったら肉球《にくきゅう》マーク")
            step(3, "**にゃん！**：9枚《まい》で3セットになったら押《お》す。自分《じぶん》で引《ひ》いたときも、人《ひと》が捨《す》てた猫《ねこ》で揃《そろ》ったときもOK")
            step(4, "山《やま》がなくなったら「お昼寝《ひるね》」で引《ひ》き分《わ》け。4回《かい》遊《あそ》んで、点数《てんすう》がいちばん多《おお》い人《ひと》が1位《い》")
        }
    }

    private var riichi: some View {
        VStack(alignment: .leading, spacing: 14) {
            title("リーチと役《やく》")
            card {
                HStack(spacing: 8) {
                    RiichiChip()
                    RubyText("あと1枚《まい》で揃《そろ》う形《かたち》になったら", size: 15, bold: true)
                }
                RubyText("捨《す》てる猫《ねこ》を選《えら》んで「**リーチ**」ボタン。そのあとは手《て》を変《か》えられない（引《ひ》いた猫《ねこ》をそのまま捨《す》てる）けど、上《あ》がれば **+10点《てん》**。言《い》わなくても上《あ》がれるよ。", size: 14)
            }
            card {
                RubyText("**役《やく》**＝点数《てんすう》が増《ふ》える揃《そろ》え方《かた》", size: 15)
                yakuRow(ScoreTable.allFamily, "3組《くみ》とも家族《かぞく》セット")
                yakuRow(ScoreTable.allSame, "3組《くみ》とも同《おな》じ猫《ねこ》3枚《まい》")
                yakuRow(ScoreTable.rolePapa, "3組《くみ》ともパパ（ママ・子猫《こねこ》も）")
                yakuRow(ScoreTable.ippatsu, "リーチしてすぐ上《あ》がる")
                RubyText("全部《ぜんぶ》の役《やく》は「？」の遊《あそ》び方《かた》で見《み》られるよ。", size: 12, color: Palette.inkSoft)
            }
        }
    }

    private var practice: some View {
        VStack(spacing: 14) {
            title(replay ? "説明《せつめい》はここまで" : "練習《れんしゅう》してみよう")
            RubyText(replay ? "練習《れんしゅう》はホームの「練習《れんしゅう》」からいつでもできるよ。" : "3つの練習《れんしゅう》で、ルールを体験《たいけん》しよう。まずは1つ目《め》から！ あとの練習《れんしゅう》はホームの「練習《れんしゅう》」からもできる。", size: 14, alignment: .center)
            TutorialTaskList(current: .basics, cleared: Set(TutorialTask.allCases.filter { app.save.cleared($0) }))
        }
    }

    // MARK: 部品

    private func title(_ text: String) -> some View {
        RubyText(text, size: 24, display: true, alignment: .center)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) { content() }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.line, lineWidth: 2))
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("・").font(AppFont.body(14, bold: true)).foregroundColor(Palette.ink)
            RubyText(text, size: 13)
        }
    }

    private func exampleSet(_ kinds: [Int], width: CGFloat = 34) -> some View {
        HStack(spacing: 2) {
            ForEach(Array(kinds.enumerated()), id: \.offset) { item in
                TileView(kind: item.element, width: width)
            }
        }
        .padding(.bottom, 7)
        .overlay(alignment: .bottom) {
            Capsule().fill(Palette.ok).frame(height: 4).padding(.horizontal, 2)
        }
    }

    private func roleColumn(_ kind: Int, _ name: String, _ mark: String) -> some View {
        VStack(spacing: 6) {
            TileView(kind: kind, width: 70)
            RubyText(name, size: 16, display: true)
            RubyText(mark, size: 12, bold: true, color: Palette.inkSoft)
        }
        .frame(maxWidth: .infinity)
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)")
                .font(AppFont.display(14))
                .foregroundColor(Palette.onPink)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Palette.pink))
            RubyText(text, size: 14)
        }
    }

    private func yakuRow(_ item: ScoreItem, _ text: String) -> some View {
        HStack {
            RubyText("**\(item.label)**　\(text)", size: 13)
            Spacer(minLength: 0)
            Text("+\(item.points)")
                .font(AppFont.body(14, bold: true))
                .foregroundColor(Palette.ink)
        }
    }
}

/// 練習の一覧（ホームの「練習」から開く）
struct PracticeView: View {
    @EnvironmentObject var app: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RubyText("練習《れんしゅう》", size: 22, display: true)
                HStack {
                    Spacer()
                    IconButton(icon: .close, label: "閉じる") { dismiss() }
                }
            }
            .padding(16)
            ScrollView {
                VStack(spacing: 14) {
                    RubyText("ルールを体験《たいけん》する練習《れんしゅう》。CPUは上《あ》がらないので、ゆっくり試《ため》せるよ。", size: 14, alignment: .center)
                    TutorialTaskList(current: TutorialTask.allCases.first { !app.save.cleared($0) }, cleared: Set(TutorialTask.allCases.filter { app.save.cleared($0) })) { task in
                        dismiss()
                        app.play(.tutorial(task))
                    }
                    Button {
                        dismiss()
                        app.replayIntro()
                    } label: {
                        RubyText("はじめの説明《せつめい》をもう一度《いちど》見《み》る", size: 15, display: true)
                    }
                    .buttonStyle(PillButtonStyle(kind: .ghost))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Palette.bg.ignoresSafeArea())
    }
}
