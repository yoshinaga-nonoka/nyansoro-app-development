// 毎日のお知らせ（端末の中だけで予約する通知。サーバーは使わない）
// 毎日19時に「今日の1局がまだだよ」。今日もう遊んだ日は出さない。先の7日分を予約し直し続ける。

import Foundation
import UserNotifications

enum DailyReminder {
    private static let idPrefix = "daily-reminder-"
    static let hour = 19

    /// 通知の許可を聞く（はじめて今日の1局を遊んだあとなど、意味が伝わる場面で呼ぶ）
    static func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    /// 予約をいったん全部消して、先の7日分を入れ直す
    static func reschedule(enabled: Bool, doneToday: Bool, streak: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: (0..<7).map { idPrefix + String($0) })
        guard enabled else { return }
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            let cal = Calendar.current
            let now = Date()
            for offset in 0..<7 {
                if offset == 0 && doneToday { continue }
                guard let day = cal.date(byAdding: .day, value: offset, to: now) else { continue }
                var comps = cal.dateComponents([.year, .month, .day], from: day)
                comps.hour = hour
                comps.minute = 0
                if let fire = cal.date(from: comps), fire <= now { continue }
                let content = UNMutableNotificationContent()
                content.title = "にゃんそろ"
                content.body = streak > 0
                    ? "今日の1局がまだだよ。\(streak)日連続の記録をのばそう"
                    : "今日の1局が届いたよ。1局だけ遊んでいく？"
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                center.add(UNNotificationRequest(identifier: idPrefix + String(offset), content: content, trigger: trigger))
            }
        }
    }
}
