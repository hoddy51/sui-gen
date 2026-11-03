import Foundation
import FamilyControls
import ManagedSettings

/// 「いま何をロックすべきか」を保存データから計算して、実際にシールドをかける。
/// アプリ本体・監視拡張・シールド拡張のどこから呼んでも同じ結果になるようにしている。
enum ShieldController {
    static let store = ManagedSettingsStore()

    /// 監視拡張から「この監視がちょうど始まった／終わった」を伝えるためのヒント
    struct Hint {
        var started: String? = nil
        var ended: String? = nil
    }

    struct Evaluation {
        var isUnlocked = false
        var unlockUntil: Date?
        var focusUntil: Date?
        var activeSchedules: [LockSchedule] = []
        var reachedLimits: [LimitRule] = []

        var blocklistActive: Bool { focusUntil != nil || !activeSchedules.isEmpty }
        /// ロックの理由が1つでもあるか（一時解除中かどうかは問わない）
        var hasLockReason: Bool { blocklistActive || !reachedLimits.isEmpty }
        /// 実際にロックしているか
        var isLocking: Bool { !isUnlocked && hasLockReason }

        var reasonText: String {
            if let until = focusUntil {
                return "集中モード中（\(until.formatted(date: .omitted, time: .shortened))まで）"
            }
            if let s = activeSchedules.first {
                return "スケジュール「\(s.name)」でロック中（\(s.timeRangeText)）"
            }
            if let l = reachedLimits.first {
                return "「\(l.name)」の今日の上限（\(l.minutes)分）に達しました"
            }
            return "ロック中です"
        }
    }

    /// 終了間際のずれを吸収するための余裕（秒）
    private static let tolerance: TimeInterval = 30

    static func evaluate(now: Date = .now, hint: Hint = .init()) -> Evaluation {
        let s = SharedStore.shared
        var e = Evaluation()

        if let until = s.unlockUntil, until.timeIntervalSince(now) > tolerance {
            e.isUnlocked = true
            e.unlockUntil = until
        }
        if let focus = s.focusSession, focus.end.timeIntervalSince(now) > tolerance {
            e.focusUntil = focus.end
        }
        for schedule in s.schedules where schedule.isEnabled {
            if hint.ended == schedule.activityName { continue }
            if hint.started == schedule.activityName {
                if schedule.startsOn(now) { e.activeSchedules.append(schedule) }
                continue
            }
            if schedule.isActive(at: now) { e.activeSchedules.append(schedule) }
        }
        let today = SharedStore.dayKey(now)
        let reached = s.limitReached
        e.reachedLimits = s.limitRules.filter { $0.isEnabled && reached[$0.id.uuidString] == today }
        return e
    }

    /// 計算結果に合わせてシールドをかけ直す
    @discardableResult
    static func refresh(now: Date = .now, hint: Hint = .init()) -> Evaluation {
        let e = evaluate(now: now, hint: hint)
        guard e.isLocking else {
            store.clearAllSettings()
            return e
        }

        var apps = Set<ApplicationToken>()
        var categories = Set<ActivityCategoryToken>()
        var webDomains = Set<WebDomainToken>()

        func add(_ selection: FamilyActivitySelection) {
            apps.formUnion(selection.applicationTokens)
            categories.formUnion(selection.categoryTokens)
            webDomains.formUnion(selection.webDomainTokens)
        }

        if e.blocklistActive { add(SharedStore.shared.blockSelection) }
        e.reachedLimits.forEach { add($0.selection) }

        store.shield.applications = apps.isEmpty ? nil : apps
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
        store.shield.webDomains = webDomains.isEmpty ? nil : webDomains
        store.shield.webDomainCategories = categories.isEmpty ? nil : .specific(categories)
        return e
    }
}

/// 集中セッションの完了処理（アプリ・拡張のどちらから呼んでも1回だけ記録される）
enum FocusLogic {
    static func completeIfNeeded(now: Date = .now) {
        let s = SharedStore.shared
        guard let session = s.focusSession, session.end.timeIntervalSince(now) <= 30 else { return }
        s.focusSession = nil
        s.updateStats(session.start) {
            $0.focusSessions += 1
            $0.focusMinutes += session.durationMinutes
        }
    }

    /// 途中でやめた場合は、集中できた分数だけ記録する
    static func interrupt(now: Date = .now) {
        let s = SharedStore.shared
        guard let session = s.focusSession else { return }
        s.focusSession = nil
        let minutes = max(0, Int(now.timeIntervalSince(session.start) / 60))
        s.updateStats(session.start) { $0.focusMinutes += minutes }
    }
}
