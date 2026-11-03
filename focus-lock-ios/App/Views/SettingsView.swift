import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var draft = UnlockSettings()

    var body: some View {
        NavigationStack {
            Form {
                if model.isSettingsLocked {
                    Section {
                        Label("ロック中は解除ルールを変更できません。", systemImage: "lock.fill")
                            .foregroundStyle(.orange)
                    }
                }

                Section {
                    Stepper("待ち時間：\(draft.waitSeconds)秒", value: $draft.waitSeconds, in: 0...300, step: 10)
                    Toggle("理由の入力を必須にする", isOn: $draft.requireReason)
                    if draft.requireReason {
                        Stepper("理由は\(draft.minReasonLength)文字以上", value: $draft.minReasonLength, in: 1...100)
                    }
                    Stepper("1日の解除回数：\(draft.maxUnlocksPerDay)回まで", value: $draft.maxUnlocksPerDay, in: 0...20)
                    Picker("1回の解除時間", selection: $draft.unlockMinutes) {
                        ForEach([15, 20, 30, 45, 60], id: \.self) { Text("\($0)分").tag($0) }
                    }
                } header: {
                    Text("解除のハードル")
                } footer: {
                    Text("ロック中に解除・集中モードの中断をするときのルールです。厳しくするほど効果的です。")
                }
                .disabled(model.isSettingsLocked)

                Section {
                    Button("保存") { model.saveUnlockSettings(draft) }
                        .disabled(model.isSettingsLocked || draft == model.unlockSettings)
                }

                Section {
                    LabeledContent("スクリーンタイム", value: model.authorization == .approved ? "許可済み" : "未許可")
                    Link("通知・権限の設定を開く", destination: URL(string: UIApplication.openSettingsURLString)!)
                } header: {
                    Text("権限")
                } footer: {
                    Text("より強力にしたい場合は、iPhoneの設定 →「スクリーンタイム」→「スクリーンタイム・パスコードを使用」をオンにし、パスコードを誰かに設定してもらうと、アプリの削除や許可の取り消しがしにくくなります。")
                }
            }
            .navigationTitle("設定")
            .onAppear { draft = model.unlockSettings }
        }
    }
}
