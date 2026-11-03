import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var minutes = 25

    private let durations = [15, 25, 45, 60, 90, 120]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statusCard
                    focusCard
                    todayCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("FocusLock")
        }
    }

    // MARK: いまの状態

    private var statusCard: some View {
        let e = model.evaluation
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: e.isLocking ? "lock.fill" : (e.isUnlocked ? "lock.open.fill" : "checkmark.circle"))
                    .font(.title2)
                    .foregroundStyle(e.isLocking ? Color.red : (e.isUnlocked ? Color.orange : Color.green))
                Text(e.isLocking ? "ロック中" : (e.isUnlocked ? "一時解除中" : "ロックなし"))
                    .font(.title3.bold())
                Spacer()
            }
            if e.hasLockReason {
                Text(e.reasonText).font(.subheadline).foregroundStyle(.secondary)
            }
            if let until = e.unlockUntil {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text("再ロックまで \(Self.countdown(until.timeIntervalSince(context.date)))")
                        .font(.subheadline.monospacedDigit())
                }
                Button("今すぐ再ロックする") { model.relockNow() }
                    .buttonStyle(.bordered)
            } else if e.isLocking {
                Button("解除の手続きをする（今日あと\(model.remainingUnlocks)回）") {
                    model.unlockPurpose = .temporary
                }
                .buttonStyle(.bordered)
                .disabled(model.remainingUnlocks == 0)
            }
        }
        .card()
    }

    // MARK: 集中モード

    @ViewBuilder
    private var focusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("集中モード", systemImage: "timer").font(.headline)

            if let session = model.focusSession {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = session.end.timeIntervalSince(context.date)
                    let progress = 1 - remaining / session.end.timeIntervalSince(session.start)
                    VStack(spacing: 12) {
                        ZStack {
                            Circle().stroke(.quaternary, lineWidth: 14)
                            Circle()
                                .trim(from: 0, to: max(0, min(1, progress)))
                                .stroke(.tint, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            VStack {
                                Text(Self.countdown(remaining))
                                    .font(.system(size: 44, weight: .bold).monospacedDigit())
                                Text("\(session.end.formatted(date: .omitted, time: .shortened)) まで")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: 220, height: 220)
                        .frame(maxWidth: .infinity)
                        .onChange(of: remaining <= 0) { _, done in
                            if done { model.checkFocusCompletion() }
                        }
                    }
                }
                Button("途中でやめる…") { model.unlockPurpose = .endFocus }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .disabled(model.remainingUnlocks == 0)
            } else {
                Text("選んだアプリを、指定した時間だけロックします。")
                    .font(.subheadline).foregroundStyle(.secondary)
                Picker("時間", selection: $minutes) {
                    ForEach(durations, id: \.self) { Text("\($0)分").tag($0) }
                }
                .pickerStyle(.segmented)
                Button {
                    model.startFocus(minutes: minutes)
                } label: {
                    Text("\(minutes)分 集中する")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                if model.blockSelection.isEmpty {
                    Text("※ 先に「ブロック」タブでロックするアプリを選んでください")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
        }
        .card()
    }

    // MARK: 今日のカウント

    private var todayCard: some View {
        let s = model.todayStats
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("今日のカウント", systemImage: "number").font(.headline)
                Spacer()
                if model.focusStreak > 0 {
                    Text("🔥 \(model.focusStreak)日連続").font(.subheadline.bold())
                }
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatTile(title: "開こうとした", value: "\(s.shieldShown)", unit: "回", icon: "hand.raised")
                StatTile(title: "我慢できた", value: "\(s.resisted)", unit: "回", icon: "checkmark.seal")
                StatTile(title: "解除した", value: "\(s.unlocks)", unit: "回", icon: "lock.open")
                StatTile(title: "集中した", value: "\(s.focusMinutes)", unit: "分", icon: "brain.head.profile")
            }
        }
        .card()
    }

    static func countdown(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded(.up)))
        return s >= 3600
            ? String(format: "%d:%02d:%02d", s / 3600, s % 3600 / 60, s % 60)
            : String(format: "%02d:%02d", s / 60, s % 60)
    }
}

struct StatTile: View {
    let title: String
    let value: String
    let unit: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon).font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.title.bold()).monospacedDigit()
                Text(unit).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
    }
}

extension View {
    func card() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
