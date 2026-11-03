import SwiftUI

/// 解除のハードル：待ち時間 → 理由の入力 → 解除（1日の回数制限つき）
struct UnlockView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    let purpose: UnlockPurpose

    @State private var remaining = 0
    @State private var started = false
    @State private var reason = ""
    @FocusState private var reasonFocused: Bool

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var settings: UnlockSettings { model.unlockSettings }
    private var waitDone: Bool { started && remaining <= 0 }
    private var reasonOK: Bool {
        !settings.requireReason
            || reason.trimmingCharacters(in: .whitespacesAndNewlines).count >= settings.minReasonLength
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if model.remainingUnlocks == 0 {
                    noUnlocksLeft
                } else if !started {
                    intro
                } else if !waitDone {
                    waiting
                } else {
                    reasonStep
                }
                Spacer()
                Button(role: .cancel) {
                    model.recordResisted()
                    dismiss()
                } label: {
                    Text("やっぱりやめる（我慢する）")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding()
            .navigationTitle(purpose == .endFocus ? "集中をやめる" : "一時解除")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(started)
        }
        .onReceive(timer) { _ in
            guard started, remaining > 0, scenePhase == .active else { return }
            remaining -= 1
        }
        .onChange(of: scenePhase) { _, phase in
            // 待っている間にアプリを離れたら最初からやり直し
            if phase != .active, started, remaining > 0 {
                remaining = settings.waitSeconds
            }
        }
    }

    private var noUnlocksLeft: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.raised.fill").font(.system(size: 56)).foregroundStyle(.orange)
            Text("今日の解除回数を使い切りました").font(.title3.bold())
            Text("1日 \(settings.maxUnlocksPerDay) 回までです。また明日。")
                .foregroundStyle(.secondary)
        }
        .padding(.top, 40)
    }

    private var intro: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.open").font(.system(size: 56)).foregroundStyle(.secondary)
            Text(purpose == .endFocus
                 ? "集中モードを途中でやめますか？"
                 : "\(settings.unlockMinutes)分だけ解除しますか？")
                .font(.title3.bold())
                .multilineTextAlignment(.center)
            Text("今日あと \(model.remainingUnlocks) 回解除できます。\n解除するには \(settings.waitSeconds) 秒待つ必要があります（アプリを離れるとやり直し）。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("待ち時間をはじめる") {
                remaining = settings.waitSeconds
                started = true
            }
            .buttonStyle(.bordered)
        }
        .padding(.top, 40)
    }

    private var waiting: some View {
        VStack(spacing: 16) {
            Text("\(remaining)")
                .font(.system(size: 96, weight: .bold).monospacedDigit())
                .contentTransition(.numericText())
                .animation(.default, value: remaining)
            Text("深呼吸して、本当に今必要か考えてみましょう。")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }

    private var reasonStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            if settings.requireReason {
                Text("解除する理由を書いてください（\(settings.minReasonLength)文字以上）")
                    .font(.headline)
                TextField("例: 仕事の連絡を確認するため", text: $reason, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)
                    .focused($reasonFocused)
                Text("\(reason.count) / \(settings.minReasonLength)文字")
                    .font(.caption).foregroundStyle(reasonOK ? Color.green : Color.secondary)
            }
            Button(role: .destructive) {
                model.performUnlock(purpose: purpose, reason: reason)
                dismiss()
            } label: {
                Text(purpose == .endFocus ? "集中モードを終了する" : "\(settings.unlockMinutes)分だけ解除する")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .disabled(!reasonOK)
        }
        .padding(.top, 20)
        .onAppear { reasonFocused = settings.requireReason }
    }
}
