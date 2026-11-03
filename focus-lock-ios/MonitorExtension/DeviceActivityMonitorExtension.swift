import DeviceActivity
import Foundation

/// アプリが閉じていても、時間になるとiOSがこの拡張を起こしてくれる。
/// 集中モード終了・一時解除の終了・スケジュールの開始/終了・利用上限の到達を処理する。
class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        ShieldController.refresh(hint: .init(started: activity.rawValue))
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        let name = activity.rawValue
        let store = SharedStore.shared

        switch name {
        case ActivityNames.focus:
            FocusLogic.completeIfNeeded()
        case ActivityNames.unlock:
            store.clearExpiredUnlock(now: Date().addingTimeInterval(30))
        default:
            break
        }
        ShieldController.refresh(hint: .init(ended: name))
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        let raw = event.rawValue
        guard raw.hasPrefix(ActivityNames.limitEventPrefix) else { return }
        let ruleID = String(raw.dropFirst(ActivityNames.limitEventPrefix.count))

        let store = SharedStore.shared
        store.markLimitReached(ruleID: ruleID)
        ShieldController.refresh()

        if let rule = store.limitRules.first(where: { $0.id.uuidString == ruleID }) {
            Notifier.send(
                id: "limit-\(ruleID)",
                title: "「\(rule.name)」は今日の上限に達しました",
                body: "\(rule.minutes)分使いました。明日またどうぞ。"
            )
        }
    }
}
