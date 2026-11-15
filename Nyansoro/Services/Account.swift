// Apple でサインイン。
//
// ■ 使えるようにするには（有料の Apple Developer Program＝年99ドルが必要）
//   1. Xcode で TARGETS「Nyansoro」→「Signing & Capabilities」→「＋ Capability」で
//      「Sign in with Apple」を追加する（iCloud 同期も使うなら「iCloud」を追加して「CloudKit」にチェック、
//      コンテナは「iCloud.<Bundle ID>」を選ぶ）
//   2. 下の AccountConfig.signInEnabled（と cloudSyncEnabled）を true にする
//   無料の個人チーム（Personal Team）ではこの機能を付けると実機に入れられないので、最初はオフにしてある。
//   オフのあいだは、サインインの画面もボタンも出ない（ゲームはそのまま遊べる）。
//
// ■ Apple から受け取れるもの
//   ユーザーごとの ID（毎回同じ）と、初回だけの名前・メール（メールは「非公開」を選ばれると転送用のアドレス）。
//   どれも端末のキーチェーン（パスワードなどを入れる安全な場所）に保存する。

import AuthenticationServices
import Foundation
import Security

enum AccountConfig {
    /// Apple でサインインを使う（有料登録と「Sign in with Apple」の Capability が必要）
    static let signInEnabled = false
    /// サインインした人の記録を iCloud（CloudKit）にも置く（「iCloud」の Capability が必要）
    static let cloudSyncEnabled = false

    static var enabled: Bool {
        #if DEBUG
        // 画面の撮影用：サインイン画面を出す（実際にはサインインしない）
        if DebugScenario.current == .onboardingSignIn { return true }
        #endif
        return signInEnabled
    }
}

/// サインインしたアカウントの記録
struct AppleAccount: Codable, Equatable {
    /// Apple がくれる、この人だけの ID（アプリごとに決まる。名前やメールではない）
    var userID: String
    /// 名前（初回だけ届く。出さない人もいる）
    var name: String?
    /// メール（初回だけ届く。転送用アドレスのこともある）
    var email: String?
    var firstSignIn = Date()
    var lastSignIn = Date()
    var signInCount = 1
}

/// キーチェーンに1件だけ保存する
enum AccountStore {
    private static let service = "nyansoro.account"
    private static let key = "apple"

    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: key]
    }

    static func load() -> AppleAccount? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return try? JSONDecoder().decode(AppleAccount.self, from: data)
    }

    static func save(_ account: AppleAccount) {
        guard let data = try? JSONEncoder().encode(account) else { return }
        let attrs: [String: Any] = [kSecValueData as String: data,
                                    kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock]
        if SecItemUpdate(query as CFDictionary, attrs as CFDictionary) == errSecItemNotFound {
            var q = query
            q.merge(attrs) { $1 }
            SecItemAdd(q as CFDictionary, nil)
        }
    }

    static func clear() {
        SecItemDelete(query as CFDictionary)
    }
}

enum AppleSignIn {
    /// 「Apple でサインイン」ボタンの結果を、保存する形にする。キャンセルなら nil
    static func account(from result: Result<ASAuthorization, Error>) -> (account: AppleAccount?, failed: Bool) {
        switch result {
        case let .success(auth):
            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential else { return (nil, true) }
            var name: String?
            if let n = cred.fullName {
                let s = PersonNameComponentsFormatter().string(from: n).trimmingCharacters(in: .whitespaces)
                if !s.isEmpty { name = s }
            }
            return (AppleAccount(userID: cred.user, name: name, email: cred.email), false)
        case let .failure(error):
            let canceled = (error as? ASAuthorizationError)?.code == .canceled
            return (nil, !canceled)
        }
    }

    /// サインインがまだ有効か（「設定」→ Apple ID → サインインとセキュリティ で連携を外すと無効になる）
    static func checkStillValid(userID: String, completion: @escaping @MainActor (Bool) -> Void) {
        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { state, _ in
            let valid = state == .authorized || state == .transferred
            Task { @MainActor in completion(valid) }
        }
    }
}
