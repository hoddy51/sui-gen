import DeviceActivity
import FamilyControls
import ManagedSettings
import SwiftUI

/// スクリーンタイムのデータ（利用時間・持ち上げ回数・通知数）を表示する拡張。
/// プライバシー保護のため、このデータは拡張の中でしか読めず、アプリ本体には渡せない。
@main
struct FocusLockReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TotalActivityReport { summary in
            TotalActivityView(summary: summary)
        }
    }
}

struct UsageSummary {
    struct AppUsage: Identifiable {
        let id: String
        let name: String
        let token: ApplicationToken?
        var duration: TimeInterval
        var pickups: Int
    }

    var total: TimeInterval = 0
    var pickups = 0
    var notifications = 0
    var apps: [AppUsage] = []
}

struct TotalActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .totalActivity
    let content: (UsageSummary) -> TotalActivityView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> UsageSummary {
        var summary = UsageSummary()
        var byApp: [String: UsageSummary.AppUsage] = [:]

        for await deviceData in data {
            for await segment in deviceData.activitySegments {
                summary.total += segment.totalActivityDuration
                summary.pickups += segment.totalPickupsWithoutApplicationActivity
                for await category in segment.categories {
                    for await app in category.applications {
                        let name = app.application.localizedDisplayName ?? "不明なアプリ"
                        let key = app.application.bundleIdentifier ?? name
                        var usage = byApp[key] ?? .init(id: key, name: name, token: app.application.token,
                                                        duration: 0, pickups: 0)
                        usage.duration += app.totalActivityDuration
                        usage.pickups += app.numberOfPickups
                        byApp[key] = usage
                        summary.pickups += app.numberOfPickups
                        summary.notifications += app.numberOfNotifications
                    }
                }
            }
        }
        summary.apps = byApp.values.sorted { $0.duration > $1.duration }
        return summary
    }
}

struct TotalActivityView: View {
    let summary: UsageSummary

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    tile("利用時間", Self.format(summary.total), "hourglass")
                    tile("持ち上げ", "\(summary.pickups)回", "iphone")
                    tile("通知", "\(summary.notifications)件", "bell")
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("アプリ別（多い順）") {
                if summary.apps.isEmpty {
                    Text("データがまだありません").foregroundStyle(.secondary)
                }
                ForEach(summary.apps.prefix(30)) { app in
                    HStack {
                        if let token = app.token {
                            Label(token).labelStyle(.titleAndIcon)
                        } else {
                            Text(app.name)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(Self.format(app.duration)).monospacedDigit()
                            Text("開いた回数 \(app.pickups)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func tile(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(.tint)
            Text(value).font(.headline).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }

    static func format(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        return minutes >= 60 ? "\(minutes / 60)時間\(minutes % 60)分" : "\(minutes)分"
    }
}
