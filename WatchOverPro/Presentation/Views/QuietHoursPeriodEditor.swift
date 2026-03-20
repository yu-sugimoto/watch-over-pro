import SwiftUI

struct QuietHoursPeriodEditor: View {
    let personId: String
    let period: QuietHoursPeriod?

    @Environment(\.dismiss) private var dismiss
    @State private var label: String
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var isEnabled: Bool
    @State private var selectedWeekdays: Set<Int>

    private let store = QuietHoursStore.shared

    private var isEditing: Bool { period != nil }

    init(personId: String, period: QuietHoursPeriod?) {
        self.personId = personId
        self.period = period

        let p = period ?? QuietHoursPeriod()
        _label = State(initialValue: p.label)
        _isEnabled = State(initialValue: p.isEnabled)
        _selectedWeekdays = State(initialValue: p.weekdays)

        var components = DateComponents()
        components.hour = p.startHour
        components.minute = p.startMinute
        _startTime = State(initialValue: Calendar.current.date(from: components) ?? Date())

        var endComponents = DateComponents()
        endComponents.hour = p.endHour
        endComponents.minute = p.endMinute
        _endTime = State(initialValue: Calendar.current.date(from: endComponents) ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本設定") {
                    TextField("ラベル（例: 就寝時間、学校）", text: $label)
                    Toggle("有効", isOn: $isEnabled)
                }

                Section("時間帯") {
                    DatePicker("開始", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("終了", selection: $endTime, displayedComponents: .hourAndMinute)
                }

                Section("曜日") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                        ForEach(QuietHoursPeriod.weekdaySymbols, id: \.id) { day in
                            Button {
                                if selectedWeekdays.contains(day.id) {
                                    if selectedWeekdays.count > 1 {
                                        selectedWeekdays.remove(day.id)
                                    }
                                } else {
                                    selectedWeekdays.insert(day.id)
                                }
                            } label: {
                                Text(day.short)
                                    .font(.subheadline.weight(.medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        selectedWeekdays.contains(day.id)
                                            ? Color.blue
                                            : Color(.tertiarySystemFill),
                                        in: .rect(cornerRadius: 10)
                                    )
                                    .foregroundStyle(selectedWeekdays.contains(day.id) ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)

                    HStack(spacing: 8) {
                        Button("毎日") {
                            selectedWeekdays = Set(1...7)
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        Button("平日") {
                            selectedWeekdays = Set([2, 3, 4, 5, 6])
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        Button("週末") {
                            selectedWeekdays = Set([1, 7])
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                }

                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            if let period {
                                store.deletePeriod(id: period.id, for: personId)
                            }
                            dismiss()
                        } label: {
                            HStack {
                                Spacer()
                                Label("この時間帯を削除", systemImage: "trash")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "時間帯を編集" : "時間帯を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: startTime)
        let startMin = calendar.component(.minute, from: startTime)
        let endHour = calendar.component(.hour, from: endTime)
        let endMin = calendar.component(.minute, from: endTime)

        let trimmedLabel = label.trimmingCharacters(in: .whitespaces)

        if let existing = period {
            let updated = QuietHoursPeriod(
                id: existing.id,
                label: trimmedLabel,
                startHour: startHour,
                startMinute: startMin,
                endHour: endHour,
                endMinute: endMin,
                isEnabled: isEnabled,
                weekdays: selectedWeekdays
            )
            store.updatePeriod(updated, for: personId)
        } else {
            let newPeriod = QuietHoursPeriod(
                label: trimmedLabel,
                startHour: startHour,
                startMinute: startMin,
                endHour: endHour,
                endMinute: endMin,
                isEnabled: isEnabled,
                weekdays: selectedWeekdays
            )
            store.addPeriod(newPeriod, for: personId)
        }
    }
}
