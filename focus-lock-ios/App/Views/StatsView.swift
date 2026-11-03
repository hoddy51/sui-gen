import Charts
import DeviceActivity
import SwiftUI

struct StatsView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case counts = "カウント"
        case screenTime = "スクリーンタイム"
        var id: String { rawValue }
    }

    @State private var tab: Tab = .counts

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("表示", selection: $tab) {
                    ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding()

                switch tab {
                case .counts: CountsView()
                case .screenTime: ScreenTimeView()
                }
            }
            .navigationTitle("記録")
        }
    }
}

// MARK: - アプリ独自のカウント（7日間）

struct CountsView: View {
    @EnvironmentObject private var model: AppModel

    private struct Point: Identifiable {
        let id = UUID()
        let day: String
        let kind: String
        let value: Int
    }

    private var points: [Point] {
        (0..<7).reversed().flatMap { ago -> [Point] in
            let (date, s) = model.stats(daysAgo: ago)
            let label = date.formatted(.dateTime.month(.defaultDigits).day())
            return [
                Point(day: label, kind: "開こうとした", value: s.shieldShown),
                Point(day: label, kind: "我慢できた", value: s.resisted),
                Point(day: label, kind: "解除した", value: s.unlocks),
            ]
        }
    }

    private var focusPoints: [Point] {
        (0..<7).reversed().map { ago in
            let (date, s) = model.stats(daysAgo: ago)
            return Point(day: date.formatted(.dateTime.month(.defaultDigits).day()), kind: "集中", value: s.focusMinutes)
        }
    }

    var body: some View {
        List {
            Section("この7日間の回数") {
                Chart(points) { p in
                    BarMark(x: .value("日", p.day), y: .value("回数", p.value))
                        .foregroundStyle(by: .value("種類", p.kind))
                        .position(by: .value("種類", p.kind))
                }
                .chartForegroundStyleScale([
                    "開こうとした": Color.orange,
                    "我慢できた": Color.green,
                    "解除した": Color.red,
                ])
                .frame(height: 220)
                .padding(.vertical, 8)
            }

            Section("集中した時間（分）") {
                Chart(focusPoints) { p in
                    BarMark(x: .value("日", p.day), y: .value("分", p.value))
                        .foregroundStyle(Color.accentColor)
                }
                .frame(height: 160)
                .padding(.vertical, 8)
                let week = (0..<7).reduce(0) { $0 + model.stats(daysAgo: $1).stats.focusMinutes }
                Text("7日間の合計：\(week / 60)時間\(week % 60)分")
            }

            Section("解除の履歴") {
                if model.unlockLogs.isEmpty {
                    Text("まだありません 👏").foregroundStyle(.secondary)
                }
                ForEach(model.unlockLogs.prefix(30)) { log in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(log.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption).foregroundStyle(.secondary)
                        Text(log.reason.isEmpty ? "（理由なし）" : log.reason)
                    }
                }
            }
        }
    }
}

// MARK: - iOS のスクリーンタイムデータ（レポート拡張が描画）

struct ScreenTimeView: View {
    enum Range: String, CaseIterable, Identifiable {
        case today = "今日"
        case week = "7日間"
        var id: String { rawValue }
    }

    @State private var range: Range = .today

    private var filter: DeviceActivityFilter {
        let calendar = Calendar.current
        let now = Date()
        let start: Date
        switch range {
        case .today:
            start = calendar.startOfDay(for: now)
        case .week:
            start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
        }
        return DeviceActivityFilter(
            segment: .daily(during: DateInterval(start: start, end: now)),
            users: .all,
            devices: .init([.iPhone])
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("期間", selection: $range) {
                ForEach(Range.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            DeviceActivityReport(.totalActivity, filter: filter)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
