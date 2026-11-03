import Foundation
import FamilyControls

// MARK: - 設定

enum AppConfig {
    /// project.yml の APP_GROUP_ID が各ターゲットの Info.plist に入っている
    static let appGroupID: String =
        Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String ?? "group.com.yourname.focuslock"
}

/// DeviceActivity の監視名・イベント名
enum ActivityNames {
    static let focus = "focus"
    static let unlock = "unlock"
    static let limits = "limits"
    static let schedulePrefix = "schedule."
    static let limitEventPrefix = "limit."
}

// MARK: - 集中モード

struct FocusSession: Codable, Equatable {
    var start: Date
    var end: Date

    var durationMinutes: Int { max(0, Int(end.timeIntervalSince(start) / 60)) }
}

// MARK: - スケジュールロック

struct LockSchedule: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String = "夜のロック"
    var isEnabled = true
    /// 0:00 からの分数
    var startMinutes: Int = 23 * 60
    var endMinutes: Int = 7 * 60
    /// Calendar の weekday（1=日 … 7=土）
    var weekdays: Set<Int> = Set(1...7)

    var activityName: String { ActivityNames.schedulePrefix + id.uuidString }

    /// 終了が開始より前なら日をまたぐ（例: 23:00〜7:00）
    var isOvernight: Bool { endMinutes < startMinutes }

    /// 長さ（分）。DeviceActivity の制約で 15 分以上が必要
    var durationMinutes: Int {
        isOvernight ? (24 * 60 - startMinutes + endMinutes) : (endMinutes - startMinutes)
    }

    var isValid: Bool { durationMinutes >= 15 && !weekdays.isEmpty }

    func isActive(at date: Date, calendar: Calendar = .current) -> Bool {
        guard isEnabled, !weekdays.isEmpty else { return false }
        let c = calendar.dateComponents([.hour, .minute, .weekday], from: date)
        let m = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        let weekday = c.weekday ?? 1
        if !isOvernight {
            return m >= startMinutes && m < endMinutes && weekdays.contains(weekday)
        }
        if m >= startMinutes { return weekdays.contains(weekday) }
        if m < endMinutes {
            // 日付をまたいだ後半は「前日」の曜日で判定
            let previous = weekday == 1 ? 7 : weekday - 1
            return weekdays.contains(previous)
        }
        return false
    }

    func startsOn(_ date: Date, calendar: Calendar = .current) -> Bool {
        weekdays.contains(calendar.component(.weekday, from: date))
    }

    static func format(_ minutes: Int) -> String {
        String(format: "%d:%02d", minutes / 60, minutes % 60)
    }

    var timeRangeText: String { "\(Self.format(startMinutes))〜\(Self.format(endMinutes))" }

    var weekdayText: String {
        if weekdays.count == 7 { return "毎日" }
        if weekdays == Set(2...6) { return "平日" }
        if weekdays == [1, 7] { return "土日" }
        return weekdays.sorted().map { Self.weekdaySymbols[$0 - 1] }.joined(separator: "・")
    }

    static let weekdaySymbols = ["日", "月", "火", "水", "木", "金", "土"]
}

// MARK: - 1日の利用上限

struct LimitRule: Codable, Identifiable {
    var id = UUID()
    var name: String = "SNS"
    var isEnabled = true
    var minutes: Int = 30
    var selection = FamilyActivitySelection()

    var eventName: String { ActivityNames.limitEventPrefix + id.uuidString }
}

// MARK: - 解除のハードル

struct UnlockSettings: Codable, Equatable {
    /// 解除前に待たされる秒数
    var waitSeconds = 30
    /// 解除理由の入力を必須にするか
    var requireReason = true
    var minReasonLength = 10
    /// 1日に解除できる回数
    var maxUnlocksPerDay = 3
    /// 1回の解除で開放される分数（15分以上）
    var unlockMinutes = 15
}

// MARK: - 記録

struct DayStats: Codable, Equatable {
    /// ブロック画面が表示された回数（目安）
    var shieldShown = 0
    /// ブロック画面で「閉じる」を選んだ・解除をやめた回数
    var resisted = 0
    /// ブロック画面から解除をリクエストした回数
    var unlockRequests = 0
    /// 実際に解除した回数
    var unlocks = 0
    /// 最後まで完了した集中セッション数
    var focusSessions = 0
    /// 集中した合計分数（途中でやめた分も含む）
    var focusMinutes = 0
}

struct UnlockLog: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var reason: String
    var minutes: Int
}

// MARK: - 便利拡張

extension FamilyActivitySelection {
    var isEmpty: Bool {
        applicationTokens.isEmpty && categoryTokens.isEmpty && webDomainTokens.isEmpty
    }

    var summaryText: String {
        var parts: [String] = []
        if !applicationTokens.isEmpty { parts.append("アプリ\(applicationTokens.count)個") }
        if !categoryTokens.isEmpty { parts.append("カテゴリ\(categoryTokens.count)個") }
        if !webDomainTokens.isEmpty { parts.append("サイト\(webDomainTokens.count)個") }
        return parts.isEmpty ? "未選択" : parts.joined(separator: "・")
    }
}
