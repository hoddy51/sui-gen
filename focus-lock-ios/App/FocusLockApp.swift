import SwiftUI

@main
struct FocusLockApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if model.authorization == .approved {
                TabView {
                    HomeView()
                        .tabItem { Label("ホーム", systemImage: "timer") }
                    BlockSettingsView()
                        .tabItem { Label("ブロック", systemImage: "lock.app.dashed") }
                    StatsView()
                        .tabItem { Label("記録", systemImage: "chart.bar") }
                    SettingsView()
                        .tabItem { Label("設定", systemImage: "gearshape") }
                }
            } else {
                OnboardingView()
            }
        }
        .sheet(item: $model.unlockPurpose) { purpose in
            UnlockView(purpose: purpose)
                .environmentObject(model)
        }
        .alert("エラー", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.reload() }
        }
    }
}
