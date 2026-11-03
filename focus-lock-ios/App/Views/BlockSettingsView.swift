import FamilyControls
import SwiftUI

struct BlockSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showPicker = false
    @State private var pickerSelection = FamilyActivitySelection()
    @State private var editingSchedule: LockSchedule?
    @State private var editingLimit: LimitRule?

    var body: some View {
        NavigationStack {
            Form {
                if model.isSettingsLocked {
                    Section {
                        Label("ロック中は設定を変更できません。変更するには、ホームから解除の手続きをしてください。",
                              systemImage: "lock.fill")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                }

                Section {
                    Button {
                        pickerSelection = model.blockSelection
                        showPicker = true
                    } label: {
                        HStack {
                            Label("ブロックするアプリ", systemImage: "apps.iphone")
                            Spacer()
                            Text(model.blockSelection.summaryText).foregroundStyle(.secondary)
                        }
                    }
                    if !model.blockSelection.applicationTokens.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(Array(model.blockSelection.applicationTokens), id: \.self) { token in
                                    Label(token).labelStyle(.iconOnly)
                                }
                            }
                        }
                    }
                } header: {
                    Text("ブロックリスト")
                } footer: {
                    Text("集中モードとスケジュールロックで、ここで選んだアプリがロックされます。")
                }

                Section {
                    ForEach(model.schedules) { schedule in
                        Button { editingSchedule = schedule } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(schedule.name).foregroundStyle(.primary)
                                    Text("\(schedule.weekdayText) \(schedule.timeRangeText)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if !schedule.isEnabled { Text("オフ").foregroundStyle(.secondary) }
                            }
                        }
                    }
                    .onDelete { model.deleteSchedules(at: $0) }
                    Button {
                        editingSchedule = LockSchedule()
                    } label: {
                        Label("スケジュールを追加", systemImage: "plus")
                    }
                } header: {
                    Text("スケジュールロック")
                } footer: {
                    Text("毎日決まった時間に、ブロックリストのアプリを自動でロックします（例: 23:00〜7:00）。")
                }

                Section {
                    ForEach(model.limitRules) { rule in
                        Button { editingLimit = rule } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(rule.name).foregroundStyle(.primary)
                                    Text("1日\(rule.minutes)分まで・\(rule.selection.summaryText)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if !rule.isEnabled { Text("オフ").foregroundStyle(.secondary) }
                            }
                        }
                    }
                    .onDelete { model.deleteLimits(at: $0) }
                    Button {
                        editingLimit = LimitRule()
                    } label: {
                        Label("利用上限を追加", systemImage: "plus")
                    }
                } header: {
                    Text("1日の利用上限")
                } footer: {
                    Text("使った時間が上限に達すると、その日はロックされます。")
                }
            }
            .disabled(model.isSettingsLocked)
            .navigationTitle("ブロック")
            .familyActivityPicker(isPresented: $showPicker, selection: $pickerSelection)
            .onChange(of: showPicker) { _, isShown in
                if !isShown { model.updateBlockSelection(pickerSelection) }
            }
            .sheet(item: $editingSchedule) { schedule in
                ScheduleEditorView(schedule: schedule) { model.saveSchedule($0) }
            }
            .sheet(item: $editingLimit) { rule in
                LimitEditorView(rule: rule) { model.saveLimit($0) }
            }
        }
    }
}

// MARK: - スケジュール編集

struct ScheduleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State var schedule: LockSchedule
    let onSave: (LockSchedule) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("名前", text: $schedule.name)
                    Toggle("有効", isOn: $schedule.isEnabled)
                }
                Section("時間") {
                    DatePicker("開始", selection: timeBinding(\.startMinutes), displayedComponents: .hourAndMinute)
                    DatePicker("終了", selection: timeBinding(\.endMinutes), displayedComponents: .hourAndMinute)
                    if schedule.isOvernight {
                        Text("日付をまたいで翌日 \(LockSchedule.format(schedule.endMinutes)) までロックします")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if schedule.durationMinutes < 15 {
                        Text("15分以上にしてください（iOSの制約）").font(.caption).foregroundStyle(.red)
                    }
                }
                Section("曜日") {
                    HStack {
                        ForEach(1...7, id: \.self) { day in
                            let on = schedule.weekdays.contains(day)
                            Button(LockSchedule.weekdaySymbols[day - 1]) {
                                if on { schedule.weekdays.remove(day) } else { schedule.weekdays.insert(day) }
                            }
                            .buttonStyle(.borderless)
                            .frame(width: 36, height: 36)
                            .background(on ? Color.accentColor : Color(.tertiarySystemFill), in: Circle())
                            .foregroundStyle(on ? Color.white : Color.primary)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle("スケジュール")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(schedule)
                        dismiss()
                    }
                    .disabled(!schedule.isValid)
                }
            }
        }
    }

    private func timeBinding(_ keyPath: WritableKeyPath<LockSchedule, Int>) -> Binding<Date> {
        Binding {
            let m = schedule[keyPath: keyPath]
            return Calendar.current.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: .now) ?? .now
        } set: { date in
            let c = Calendar.current.dateComponents([.hour, .minute], from: date)
            schedule[keyPath: keyPath] = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        }
    }
}

// MARK: - 利用上限編集

struct LimitEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State var rule: LimitRule
    let onSave: (LimitRule) -> Void
    @State private var showPicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("名前（例: SNS、動画）", text: $rule.name)
                    Toggle("有効", isOn: $rule.isEnabled)
                }
                Section("対象") {
                    Button {
                        showPicker = true
                    } label: {
                        HStack {
                            Text("アプリを選ぶ")
                            Spacer()
                            Text(rule.selection.summaryText).foregroundStyle(.secondary)
                        }
                    }
                }
                Section("上限") {
                    Stepper("1日 \(rule.minutes) 分まで", value: $rule.minutes, in: 5...240, step: 5)
                }
            }
            .navigationTitle("利用上限")
            .navigationBarTitleDisplayMode(.inline)
            .familyActivityPicker(isPresented: $showPicker, selection: $rule.selection)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(rule)
                        dismiss()
                    }
                    .disabled(rule.selection.isEmpty || rule.name.isEmpty)
                }
            }
        }
    }
}
