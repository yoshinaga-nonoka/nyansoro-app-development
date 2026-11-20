// サインインした人の記録を iCloud（CloudKit のプライベートデータベース）に置く。
// 機種変更しても、同じ Apple ID でサインインすれば記録を引きつげる。サーバー代はかからない。
// AccountConfig.cloudSyncEnabled が false のあいだは何もしない
// （iCloud の Capability がないアプリで CloudKit を呼ぶと止まってしまうため）。

import CloudKit
import Foundation

enum CloudSave {
    static var enabled: Bool { AccountConfig.signInEnabled && AccountConfig.cloudSyncEnabled }

    private static let recordType = "NyansoroSave"

    private static var database: CKDatabase { CKContainer.default().privateCloudDatabase }

    private static func recordID(_ user: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "save-" + user.filter { $0.isLetter || $0.isNumber })
    }

    /// iCloud の記録（まだなければ nil）
    static func load(user: String) async throws -> SaveData? {
        do {
            let record = try await database.record(for: recordID(user))
            guard let data = record["json"] as? Data else { return nil }
            return try JSONDecoder().decode(SaveData.self, from: data)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    /// 今の記録で iCloud を上書きする
    static func store(_ save: SaveData, user: String) async throws {
        let record = CKRecord(recordType: recordType, recordID: recordID(user))
        record["json"] = try JSONEncoder().encode(save)
        record["rounds"] = save.stats.rounds
        record["rank"] = save.progress.rank
        _ = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
    }
}
