# にゃんそろ（iOS版 v0.1・SwiftUI）

猫の絵柄を「3枚セット」×3組そろえる、かんたんな麻雀風ゲームの iPhone / iPad アプリ。

## 動かし方（Mac）
1. `Nyansoro.xcodeproj` をダブルクリックして Xcode で開く（Xcode 16 以降）
2. 画面上部の実行先で iPhone のシミュレーター（例：iPhone 16）を選び、▶︎ を押す
3. 自分の iPhone で動かすとき
   - 左の「Nyansoro」→ TARGETS「Nyansoro」→「Signing & Capabilities」で Team に自分の Apple ID を選ぶ
   - Bundle Identifier は App Store Connect に登録した `com.nonoka.nyansoro`（変えない。ほかの Apple ID で試すときだけ一時的に変える）

### 自分の iPhone で試す（実機テスト）
1. Xcode → Settings… → Accounts で、左下の「＋」から自分の Apple ID を追加する（無料でよい）
2. iPhone をケーブルで Mac につなぎ、iPhone に出る「このコンピュータを信頼しますか？」で「信頼」
3. iPhone の 設定 → プライバシーとセキュリティ → デベロッパモード をオンにして再起動する（項目は手順2の後に出る）
4. Xcode 左の「Nyansoro」→ TARGETS「Nyansoro」→「Signing & Capabilities」
   - 「Automatically manage signing」にチェック
   - Team で自分の Apple ID（Personal Team）を選ぶ
   - Bundle Identifier は `com.nonoka.nyansoro` のまま（App Store Connect に登録したもの）
5. 画面上部の実行先で、つないだ iPhone を選んで ▶︎
6. 初回だけ iPhone 側で止められたら：設定 → 一般 → VPNとデバイス管理 → 自分の Apple ID のデベロッパ を「信頼」して、もう一度 ▶︎

無料の Apple ID で入れたアプリは7日で開けなくなる（もう一度 ▶︎ で入れ直せる）。
2回目からは、同じ Wi-Fi なら Xcode の Window → Devices and Simulators で「Connect via network」にするとケーブルなしで入れられる。

開けない・赤いエラーが出たときは、エラーの文章をそのまま送ってください。
プロジェクトファイルが壊れている場合は、ターミナルで `brew install xcodegen` → このフォルダで `xcodegen` を実行すると作り直せます（`project.yml`）。

## 入っている機能
- 初めての起動：ホームの前に遊び方の説明（勝ち方・セット・パパ／ママ／子猫の見分け方・招き猫・順番・リーチと役）→ 練習へ。「？」の遊び方や「練習」から見直せる
- 練習（チュートリアルタスク）3つ：「3枚セットで上がってみよう」「リーチして上がろう」「役を作って点数を上げよう」。決まった配牌で、CPU は上がらない
- リーチ：あと1枚の形で宣言すると、手を変えられない代わりに上がれば +10点（言わなくても上がれる）
- 役：自分で引いて上がり・リーチ・すぐにゃん・招き猫なし・全部同じ猫・全部家族・家族と兄弟・最後の1枚・パパ／ママ／子猫そろい・ひと家族だらけ（`NyansoroCore/Sources/NyansoroCore/Score.swift`）
- Apple でサインイン（有料の Apple Developer Program が必要なので、今はオフ。下の「Apple でサインインを使う」）
- CPU対戦（ランクアップ制）：子猫 → 家猫 → 野良猫 → ボス猫 → 猫神様
- 「？」ボタン：遊び方。対戦中は「今の手」（揃ったセット・足りない猫・待っている猫）も見られる
- ヒント（おすすめの肉球マーク・セットの線・あと何枚）、ふりがな、自動でにゃん！、音、振動、CPUの速さ、マット
- 広告の受け皿：開発用ビルドでは本物の代わりに「テスト表示」の広告が出る（AdMob は未接続）
- オンライン対戦はボタンだけ（準備中）

## フォルダ構成
```
Nyansoro.xcodeproj        Xcode のプロジェクト（フォルダ同期。ファイルを足すと自動で入る）
Nyansoro/                 iOS アプリ（SwiftUI）
  App/                    入口・画面の切り替え・アプリ全体の状態
  Game/GameController     対戦の進行役（CPU の間合い・練習の台本）
  Views/                  画面（タイトル・ランク選択・対戦・結果・遊び方・設定）
  Views/Common/           牌・猫の絵・ふりがな・ボタンなどの部品
  Services/               セーブ・効果音と振動・広告
  Theme/                  配色（ライト／ダーク）とフォント
  Resources/              フォント（SIL Open Font License）・アイコン
NyansoroCore/             ルール本体（画面に依存しない Swift パッケージ）
  Sources/NyansoroCore/   牌・上がり判定・点数・進行・CPU・ランク・広告を出す決まり
  Sources/nyansoro-sim/   CPU の強さのバランス確認
  Tests/                  ルールのテスト
```
`NyansoroCore/Sources/NyansoroCore` のファイルは、アプリにもそのまま取り込まれています（同じモジュール）。

## ルールのテスト（ターミナル）
```bash
cd NyansoroCore
swift test                                   # ルールのテスト（39件）
swift run -c release nyansoro-sim 150        # CPU の強さ（各ランクで1位になる割合）と1局の長さ
```

## 文章とふりがな
画面の文章は「漢字《よみ》」で書く（青空文庫式）。`RubyText("猫《ねこ》を捨《す》てる")` で漢字の上に読みが出る。
`**ここ**` で太字。区切りが自動で決まらないときは `｜CPU《シーピーユー》`。設定の「ふりがな」で消せる。

## 広告（AdMob）を入れる
1. AdMob でアプリと広告ユニット（リワード・インタースティシャル）を作る
2. Xcode の File → Add Package Dependencies で Google Mobile Ads SDK を追加
3. Info.plist に `GADApplicationIdentifier` と SKAdNetwork の一覧を追加（Build Settings の Info.plist 設定）
4. `Services/Ads.swift` の `AdService` に合わせて `AdMobAdService` を作り、`AppModel.ads` で差し替える
5. 子どもも遊ぶ前提なので、初回に年齢区分を聞き、13歳未満には「子ども向け扱い」の設定で広告を読み込む。広告の内容の上限は G か PG
6. App Tracking Transparency（追跡の許可）とプライバシーポリシーのページを用意する

広告を「いつ出すか」は `NyansoroCore/Sources/NyansoroCore/AdPolicy.swift`（練習中・対局中・最初の3試合は出さない、全画面は2試合に1回まで・3分あける、リワードは1日3回まで）。

## Apple でサインインを使う
今は `Nyansoro/Services/Account.swift` の `AccountConfig.signInEnabled = false`（オフ）。オフのあいだは、サインインの画面もボタンも出ないので、無料の Apple ID（Personal Team）のまま実機で試せます。

有料の Apple Developer Program（年99ドル）に登録したら：
1. Xcode で TARGETS「Nyansoro」→「Signing & Capabilities」→ Team を有料のチームにする
2. 「＋ Capability」→「Sign in with Apple」を追加
3. 機種変更しても記録を引きつぐなら「＋ Capability」→「iCloud」→「CloudKit」にチェックし、コンテナ「iCloud.<Bundle ID>」を作って選ぶ
4. `AccountConfig.signInEnabled` を `true`（iCloud も使うなら `cloudSyncEnabled` も `true`）にする

- 初回の説明の最初のページに「Apple でサインイン」と「あとで」が出る（審査の決まりで、サインインしなくても遊べるようにしてある）。設定からもサインイン・サインアウトできる
- Apple から受け取るのは、その人だけの ID と、初回だけの名前・メール。端末のキーチェーンに保存する
- iCloud には、セーブデータ（ランク・★・称号・成績・練習など）をそのまま置く。遊んだ局数が多い方の記録を残す
