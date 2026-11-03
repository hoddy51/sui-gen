import FamilyControls
import Foundation
import SwiftUI
import UserNotifications

enum UnlockPurpose: String, Identifiable {
    /// 一時的に全部解除する
    case temporary
    /// 集中モードを途中でやめる
    case endFocus

    var id: String { rawValue }
}

@MainActor
final class AppModel: ObservableObject {
    private let store = SharedStore.shared

    @Published var authorization: AuthorizationStatus = AuthorizationCenter.shared.authorizationStatus
    @Published private(set) var blockSelection = FamilyActivitySelection()
    @Published private(set) var focusSession: FocusSession?
    @Published private(set) var schedules: [LockSchedule] = []
    @Published private(set) var limitRules: [LimitRule] = []
    @Published private(set) var unlockSettings = UnlockSettings()
    @Published private(set) var evaluation = ShieldController.Evaluation()
    @Published private(set) var allStats: [String: DayStats] = [:]
    @Published private(set) var unlockLogs: [UnlockLog] = []

    @Published var unlockPurpose: UnlockPurpose?
    @Published var errorMessage: String?

    init() {
        reload()
    }

    // MARK: - 読み込み

    func reload() {
        FocusLogic.completeIfNeeded()
        store.clearExpiredUnlock()

        authorization = AuthorizationCenter.shared.authorizationStatus
        blockSelection = store.blockSelection
        focusSession = store.focusSession
        schedules = store.schedules
        limitRules = store.limitRules
        unlockSettings = store.unlockSettings
        allStats = store.allStats
        unlockLogs = store.unlockLogs
        evaluation = ShieldController.refresh()

        // ロック画面から「解除をリクエスト」して10分以内なら、解除画面を開く
        if let requested = store.pendingUnlockRequestAt {
            store.pendingUnlockRequestAt = nil
            if Date().timeIntervalSince(requested) < 600, evaluation.isLocking {
                unlockPurpose = .temporary
            }
        }
    }

    private func refreshShield() {
        evaluation = ShieldController.refresh()
        allStats = store.allStats
    }

    // MARK: - 権限

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            errorMessage = "スクリーンタイムの許可が得られませんでした（\(error.localizedDescription)）"
        }
        authorization = AuthorizationCenter.shared.authorizationStatus
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    // MARK: - ロック中は設定変更不可（抜け道防止）

    var isSettingsLocked: Bool { evaluation.isLocking }

    // MARK: - ブロックリスト

    func updateBlockSelection(_ selection: FamilyActivitySelection) {
        guard !isSettingsLocked else { return }
        store.blockSelection = selection
        blockSelection = selection
        refreshShield()
    }

    // MARK: - 集中モード

    func startFocus(minutes: Int) {
        guard !blockSelection.isEmpty else {
            errorMessage = "先に「ブロック」タブでロックするアプリを選んでください"
            return
        }
        let now = Date()
        let session = FocusSession(start: now, end: now.addingTimeInterval(TimeInterval(minutes * 60)))
        do {
            try ActivityScheduler.scheduleOneShot(name: ActivityNames.focus, end: session.end)
        } catch {
            errorMessage = "集中モードを開始できませんでした（\(error.localizedDescription)）"
            return
        }
        store.focusSession = session
        focusSession = session
        Notifier.send(id: "focus-end", title: "集中モード終了 🎉",
                      body: "\(minutes)分の集中、おつかれさまでした！",
                      after: TimeInterval(minutes * 60))
        refreshShield()
    }

    /// 時間が来たときの完了処理（ホーム画面のタイマーから呼ぶ）
    func checkFocusCompletion() {
        guard let session = focusSession, session.end <= Date() else { return }
        FocusLogic.completeIfNeeded()
        focusSession = store.focusSession
        refreshShield()
    }

    // MARK: - 解除

    var todayStats: DayStats { allStats[SharedStore.dayKey(.now)] ?? DayStats() }

    var remainingUnlocks: Int { max(0, unlockSettings.maxUnlocksPerDay - todayStats.unlocks) }

    func performUnlock(purpose: UnlockPurpose, reason: String) {
        guard remainingUnlocks > 0 else { return }
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)

        switch purpose {
        case .endFocus:
            FocusLogic.interrupt()
            ActivityScheduler.cancel(ActivityNames.focus)
            Notifier.cancel(["focus-end"])
            store.updateStats { $0.unlocks += 1 }
            store.appendUnlockLog(UnlockLog(date: .now, reason: "【集中を中断】" + trimmed, minutes: 0))

        case .temporary:
            let minutes = unlockSettings.unlockMinutes
            let until = Date().addingTimeInterval(TimeInterval(minutes * 60))
            do {
                try ActivityScheduler.scheduleOneShot(name: ActivityNames.unlock, end: until)
            } catch {
                errorMessage = "解除できませんでした（\(error.localizedDescription)）"
                return
            }
            store.unlockUntil = until
            store.updateStats { $0.unlocks += 1 }
            store.appendUnlockLog(UnlockLog(date: .now, reason: trimmed, minutes: minutes))
            Notifier.send(id: "relock-soon", title: "まもなく再ロックします",
                          body: "あと1分で一時解除が終わります。",
                          after: TimeInterval(max(1, minutes * 60 - 60)))
        }
        reload()
    }

    func relockNow() {
        store.unlockUntil = nil
        ActivityScheduler.cancel(ActivityNames.unlock)
        Notifier.cancel(["relock-soon"])
        reload()
    }

    func recordResisted() {
        store.updateStats { $0.resisted += 1 }
        allStats = store.allStats
    }

    // MARK: - スケジュール

    func saveSchedule(_ schedule: LockSchedule) {
        guard !isSettingsLocked else { return }
        if let i = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[i] = schedule
        } else {
            schedules.append(schedule)
        }
        persistSchedules()
    }

    func deleteSchedules(at offsets: IndexSet) {
        guard !isSettingsLocked else { return }
        schedules.remove(atOffsets: offsets)
        persistSchedules()
    }

    private func persistSchedules() {
        store.schedules = schedules
        do {
            try ActivityScheduler.syncSchedules(schedules)
        } catch {
            errorMessage = "スケジュールの登録に失敗しました（\(error.localizedDescription)）"
        }
        refreshShield()
    }

    // MARK: - 利用上限

    func saveLimit(_ rule: LimitRule) {
        guard !isSettingsLocked else { return }
        if let i = limitRules.firstIndex(where: { $0.id == rule.id }) {
            limitRules[i] = rule
        } else {
            limitRules.append(rule)
        }
        persistLimits()
    }

    func deleteLimits(at offsets: IndexSet) {
        guard !isSettingsLocked else { return }
        limitRules.remove(atOffsets: offsets)
        persistLimits()
    }

    private func persistLimits() {
        store.limitRules = limitRules
        do {
            try ActivityScheduler.syncLimits(limitRules)
        } catch {
            errorMessage = "利用上限の登録に失敗しました（\(error.localizedDescription)）"
        }
        refreshShield()
    }

    // MARK: - 解除ルール

    func saveUnlockSettings(_ settings: UnlockSettings) {
        guard !isSettingsLocked else { return }
        store.unlockSettings = settings
        unlockSettings = settings
    }

    // MARK: - 記録

    func stats(daysAgo: Int) -> (date: Date, stats: DayStats) {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
        return (date, allStats[SharedStore.dayKey(date)] ?? DayStats())
    }

    /// 集中セッションを完了した日が何日連続しているか
    var focusStreak: Int {
        var streak = 0
        var day = 0
        // 今日まだやっていなくても、昨日まで続いていれば連続扱い
        if stats(daysAgo: 0).stats.focusSessions == 0 { day = 1 }
        while stats(daysAgo: day).stats.focusSessions > 0 {
            streak += 1
            day += 1
        }
        return streak
    }
}
