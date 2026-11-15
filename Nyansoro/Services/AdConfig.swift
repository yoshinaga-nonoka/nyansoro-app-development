// 広告の ID。アプリ ID は Nyansoro-Info.plist の GADApplicationIdentifier。
//
// 開発用ビルド（Debug）では Google 公式の「テスト広告」を使う。本物の広告を自分で押すと
// AdMob のアカウントが止められることがあるので、開発中は必ずテスト広告にする。
// リリース用（Release）は、AdMob で作った広告ユニットの ID を入れる。空のあいだは広告を出さない。

enum AdConfig {
    static let appID = "ca-app-pub-9015776457528965~2088043952"

    #if DEBUG
    static let rewardedUnitID = "ca-app-pub-3940256099942544/1712485313"      // Google 公式のテスト用（リワード）
    static let interstitialUnitID = "ca-app-pub-3940256099942544/4411468910"  // Google 公式のテスト用（インタースティシャル）
    #else
    static let rewardedUnitID = ""      // ← AdMob の「リワード」広告ユニット ID（ca-app-pub-…/…）
    static let interstitialUnitID = ""  // ← AdMob の「インタースティシャル」広告ユニット ID
    #endif

    static var enabled: Bool { !rewardedUnitID.isEmpty || !interstitialUnitID.isEmpty }
}
