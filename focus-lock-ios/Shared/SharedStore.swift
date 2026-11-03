import Foundation
import FamilyControls

/// アプリ本体と各拡張機能で共有するデータ（App Group の UserDefaults に JSON で保存）
final class SharedStore {
    static let shared = SharedStore()

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private enum Key {
        static let blockSelection = "blockSelection"
        static let focusSession = "focusSession"
        static let schedules = "schedules"
        static let limitRules = "limitRules"
        static let unlockSettings = "unlockSettings"
        static let unlockUntil = "unlockUntil"
        static let limitReached = "limitReached"
        static let stats = "stats"
        static let unlockLogs = "unlockLogs"
        static let pendingUnlockRequestAt = "pendingUnlockRequestAt"
    }

    init(defaults: UserDefaults? = UserDefaults(suiteName: AppConfig.appGroupID)) {
        self.defaults = defaults ?? .standard
    }

    // MARK: 汎用

    private func load<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    private func save<T: Encodable>(_ value: T?, _ key: String) {
        if let value, let data = try? encoder.encode(value) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: 設定・状態

    var blockSelection: FamilyActivitySelection {
        get { load(FamilyActivitySelection.self, Key.blockSelection) ?? FamilyActivitySelection() }
        set { save(newValue, Key.blockSelection) }
    }

    var focusSession: FocusSession? {
        get { load(FocusSession.self, Key.focusSession) }
        set { save(newValue, Key.focusSession) }
    }

    var schedules: [LockSchedule] {
        get { load([LockSchedule].self, Key.schedules) ?? [] }
        set { save(newValue, Key.schedules) }
    }

    var limitRules: [LimitRule] {
        get { load([LimitRule].self, Key.limitRules) ?? [] }
        set { save(newValue, Key.limitRules) }
    }

    var unlockSettings: UnlockSettings {
        get { load(UnlockSettings.self, Key.unlockSettings) ?? UnlockSettings() }
        set { save(newValue, Key.unlockSettings) }
    }

    var unlockUntil: Date? {
        get { load(Date.self, Key.unlockUntil) }
        set { save(newValue, Key.unlockUntil) }
    }

    /// 上限に達したルール: ruleID -> 達した日の dayKey
    var limitReached: [String: String] {
        get { load([String: String].self, Key.limitReached) ?? [:] }
        set { save(newValue, Key.limitReached) }
    }

    var pendingUnlockRequestAt: Date? {
        get { load(Date.self, Key.pendingUnlockRequestAt) }
        set { save(newValue, Key.pendingUnlockRequestAt) }
    }

    func clearExpiredUnlock(now: Date = .now) {
        if let until = unlockUntil, until <= now { unlockUntil = nil }
    }

    func markLimitReached(ruleID: String, now: Date = .now) {
        var reached = limitReached
        let today = Self.dayKey(now)
        // 古い日付のものは掃除
        reached = reached.filter { $0.value == today }
        reached[ruleID] = today
        limitReached = reached
    }

    // MARK: 記録

    var allStats: [String: DayStats] {
        get { load([String: DayStats].self, Key.stats) ?? [:] }
        set { save(newValue, Key.stats) }
    }

    func stats(for date: Date) -> DayStats {
        allStats[Self.dayKey(date)] ?? DayStats()
    }

    func updateStats(_ date: Date = .now, _ body: (inout DayStats) -> Void) {
        var all = allStats
        let key = Self.dayKey(date)
        var day = all[key] ?? DayStats()
        body(&day)
        all[key] = day
        allStats = all
    }

    var unlockLogs: [UnlockLog] {
        get { load([UnlockLog].self, Key.unlockLogs) ?? [] }
        set { save(newValue, Key.unlockLogs) }
    }

    func appendUnlockLog(_ log: UnlockLog) {
        var logs = unlockLogs
        logs.insert(log, at: 0)
        unlockLogs = Array(logs.prefix(200))
    }

    // MARK: 日付キー

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dayKey(_ date: Date) -> String {
        dayFormatter.timeZone = .current
        return dayFormatter.string(from: date)
    }
}
