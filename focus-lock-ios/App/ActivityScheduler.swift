import DeviceActivity
import Foundation

/// DeviceActivityCenter への登録（＝アプリが閉じていても決まった時刻に監視拡張を起こしてもらう）
enum ActivityScheduler {
    static let center = DeviceActivityCenter()

    /// 1回きりの監視。end の時刻に intervalDidEnd が呼ばれる。
    /// iOS の制約で監視は 15 分以上必要なので、短い場合は開始を過去にずらして帳尻を合わせる。
    static func scheduleOneShot(name: String, end: Date) throws {
        let calendar = Calendar.current
        let now = Date()
        var start = calendar.dateInterval(of: .minute, for: now)?.start ?? now
        if end.timeIntervalSince(start) < 15 * 60 {
            start = end.addingTimeInterval(-15 * 60)
        }
        let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(components, from: start),
            intervalEnd: calendar.dateComponents(components, from: end),
            repeats: false
        )
        let activity = DeviceActivityName(name)
        center.stopMonitoring([activity])
        try center.startMonitoring(activity, during: schedule)
    }

    static func cancel(_ name: String) {
        center.stopMonitoring([DeviceActivityName(name)])
    }

    /// 毎日くり返すスケジュールロックを登録し直す（曜日は拡張側で判定）
    static func syncSchedules(_ schedules: [LockSchedule]) throws {
        let old = center.activities.filter { $0.rawValue.hasPrefix(ActivityNames.schedulePrefix) }
        center.stopMonitoring(old)

        var firstError: Error?
        for s in schedules where s.isEnabled && s.isValid {
            let schedule = DeviceActivitySchedule(
                intervalStart: DateComponents(hour: s.startMinutes / 60, minute: s.startMinutes % 60),
                intervalEnd: DateComponents(hour: s.endMinutes / 60, minute: s.endMinutes % 60),
                repeats: true
            )
            do {
                try center.startMonitoring(DeviceActivityName(s.activityName), during: schedule)
            } catch {
                firstError = firstError ?? error
            }
        }
        if let firstError { throw firstError }
    }

    /// 1日の利用上限を登録し直す（0:00〜23:59 を毎日くり返し、上限到達でイベント発火）
    static func syncLimits(_ rules: [LimitRule]) throws {
        let activity = DeviceActivityName(ActivityNames.limits)
        center.stopMonitoring([activity])

        let enabled = rules.filter { $0.isEnabled && !$0.selection.isEmpty }
        guard !enabled.isEmpty else { return }

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for rule in enabled {
            events[DeviceActivityEvent.Name(rule.eventName)] = makeEvent(rule)
        }
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
            repeats: true
        )
        try center.startMonitoring(activity, during: schedule, events: events)
    }

    private static func makeEvent(_ rule: LimitRule) -> DeviceActivityEvent {
        let threshold = DateComponents(minute: rule.minutes)
        if #available(iOS 17.4, *) {
            // 途中で設定を変えても、今日すでに使った分を含めて数える
            return DeviceActivityEvent(
                applications: rule.selection.applicationTokens,
                categories: rule.selection.categoryTokens,
                webDomains: rule.selection.webDomainTokens,
                threshold: threshold,
                includesPastActivity: true
            )
        }
        return DeviceActivityEvent(
            applications: rule.selection.applicationTokens,
            categories: rule.selection.categoryTokens,
            webDomains: rule.selection.webDomainTokens,
            threshold: threshold
        )
    }
}
