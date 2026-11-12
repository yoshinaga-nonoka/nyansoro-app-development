// セーブデータ（ランク・★・設定・広告の回数）。端末の UserDefaults に JSON で保存する。

import Foundation

enum Speed: String, Codable, CaseIterable {
    case slow, normal, fast

    var label: String {
        switch self {
        case .slow: return "ゆっくり"
        case .normal: return "普通《ふつう》"
        case .fast: return "速《はや》い"
        }
    }

    /// CPU が山から引くまでの秒数
    var draw: Double {
        switch self {
        case .slow: return 0.6
        case .normal: return 0.33
        case .fast: return 0.15
        }
    }

    /// CPU が捨てる猫を考える秒数
    var think: Double {
        switch self {
        case .slow: return 1.25
        case .normal: return 0.76
        case .fast: return 0.36
        }
    }
}

struct Settings: Codable, Equatable {
    var hints = true
    var autoNyan = true
    var speed: Speed = .normal
    var sound = true
    var haptics = true
    var mat: MatId = .ramune
    var furigana = true

    init() {}

    // 項目が増えても古いセーブを読めるように、無い項目は初期値にする
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings()
        hints = try c.decodeIfPresent(Bool.self, forKey: .hints) ?? d.hints
        autoNyan = try c.decodeIfPresent(Bool.self, forKey: .autoNyan) ?? d.autoNyan
        speed = try c.decodeIfPresent(Speed.self, forKey: .speed) ?? d.speed
        sound = try c.decodeIfPresent(Bool.self, forKey: .sound) ?? d.sound
        haptics = try c.decodeIfPresent(Bool.self, forKey: .haptics) ?? d.haptics
        mat = try c.decodeIfPresent(MatId.self, forKey: .mat) ?? d.mat
        furigana = try c.decodeIfPresent(Bool.self, forKey: .furigana) ?? d.furigana
    }
}

struct SaveData: Codable, Equatable {
    var progress = RankProgress()
    var settings = Settings()
    var ads = AdPolicy()

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        progress = try c.decodeIfPresent(RankProgress.self, forKey: .progress) ?? RankProgress()
        settings = try c.decodeIfPresent(Settings.self, forKey: .settings) ?? Settings()
        ads = try c.decodeIfPresent(AdPolicy.self, forKey: .ads) ?? AdPolicy()
    }
}

enum SaveStore {
    private static let key = "nyansoro.save.v1"

    static func load() -> SaveData {
        guard let data = UserDefaults.standard.data(forKey: key),
              let save = try? JSONDecoder().decode(SaveData.self, from: data) else { return SaveData() }
        return save
    }

    static func write(_ save: SaveData) {
        guard let data = try? JSONEncoder().encode(save) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
