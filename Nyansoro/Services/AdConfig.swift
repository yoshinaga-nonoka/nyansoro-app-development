// 広告の ID。アプリ ID は Nyansoro-Info.plist の GADApplicationIdentifier。
//
// 開発用ビルド（Debug）では Google 公式の「テスト広告」を使う。本物の広告を自分で押すと
// AdMob のアカウントが止められることがあるので、開発中は必ずテスト広告にする。
// リリース用（Release）は、AdMob で作った本物の広告ユニットの ID（空にすると広告を出さない）。

enum AdConfig {
    static let appID = "ca-app-pub-9015776457528965~2088043952"

    #if DEBUG
    static let rewardedUnitID = "ca-app-pub-3940256099942544/1712485313"      // Google 公式のテスト用（リワード）
    static let interstitialUnitID = "ca-app-pub-3940256099942544/4411468910"  // Google 公式のテスト用（インタースティシャル）
    #else
    static let rewardedUnitID = "ca-app-pub-9015776457528965/3169850473"      // AdMob の「リワード」広告ユニット
    static let interstitialUnitID = "ca-app-pub-9015776457528965/9571782304"  // AdMob の「インタースティシャル」広告ユニット
    #endif

    static var enabled: Bool { !rewardedUnitID.isEmpty || !interstitialUnitID.isEmpty }
}
