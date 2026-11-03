import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
            Text("FocusLock")
                .font(.largeTitle.bold())
            VStack(alignment: .leading, spacing: 12) {
                feature("timer", "集中モード中は選んだアプリをロック")
                feature("calendar.badge.clock", "決まった時間に自動でロック")
                feature("hourglass", "1日の利用時間に上限を設定")
                feature("number", "開こうとした回数・我慢した回数を記録")
            }
            .padding()
            Text("アプリをロックするために「スクリーンタイム」へのアクセスを許可してください。データはこのiPhoneの中だけに保存されます。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
            Button {
                Task { await model.requestAuthorization() }
            } label: {
                Text("許可してはじめる")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            if model.authorization == .denied {
                Text("許可されていません。設定アプリ →「スクリーンタイム」から FocusLock を許可してください。")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding(.bottom)
    }

    private func feature(_ icon: String, _ text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.body)
    }
}
