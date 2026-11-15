// セーブデータ（ランク・★・設定・広告の回数・練習と説明）。端末の UserDefaults に JSON で保存する。
// Apple でサインインしていて iCloud 同期がオンなら、iCloud にも同じ JSON を置く（Services/CloudSave.swift）。

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
    /// 毎日のお知らせ（今日の1局）
    var reminders = true

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
        reminders = try c.decodeIfPresent(Bool.self, forKey: .reminders) ?? d.reminders
    }
}

/// 初めて起動したときの説明（ホームの前に出す）
struct OnboardingState: Codable, Equatable {
    /// 説明を最後まで見た（または飛ばした）
    var introDone = false
    /// Apple でサインインを案内した（「あとで」を押した場合も含む）
    var signInOffered = false
}

struct SaveData: Codable, Equatable {
    var progress = RankProgress()
    var settings = Settings()
    var ads = AdPolicy()
    var streak = StreakState()
    var daily: DailyResult?
    /// 通知の許可をもう聞いたか
    var askedReminders = false
    /// 目標・成績（上達のしくみ）
    var missions = MissionProgress()
    var stats = PlayStats()
    /// 初回の説明
    var onboarding = OnboardingState()
    /// クリアした練習（TutorialTask の rawValue）
    var tutorialTasks: [String] = []

    init() {}

    func cleared(_ task: TutorialTask) -> Bool { tutorialTasks.contains(task.rawValue) }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        progress = try c.decodeIfPresent(RankProgress.self, forKey: .progress) ?? RankProgress()
        settings = try c.decodeIfPresent(Settings.self, forKey: .settings) ?? Settings()
        ads = try c.decodeIfPresent(AdPolicy.self, forKey: .ads) ?? AdPolicy()
        streak = try c.decodeIfPresent(StreakState.self, forKey: .streak) ?? StreakState()
        daily = try c.decodeIfPresent(DailyResult.self, forKey: .daily)
        askedReminders = try c.decodeIfPresent(Bool.self, forKey: .askedReminders) ?? false
        missions = try c.decodeIfPresent(MissionProgress.self, forKey: .missions) ?? MissionProgress()
        stats = try c.decodeIfPresent(PlayStats.self, forKey: .stats) ?? PlayStats()
        // 説明ができる前から遊んでいた人には、初回の説明は出さない
        var played = OnboardingState()
        played.introDone = progress.tutorialDone || stats.rounds > 0
        onboarding = try c.decodeIfPresent(OnboardingState.self, forKey: .onboarding) ?? played
        tutorialTasks = try c.decodeIfPresent([String].self, forKey: .tutorialTasks) ?? (progress.tutorialDone ? [TutorialTask.basics.rawValue] : [])
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
