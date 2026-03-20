import SwiftUI

struct QuietHoursListView: View {
    let personId: String
    let personName: String
    let personColorHex: String

    @State private var periods: [QuietHoursPeriod] = []
    @State private var showAddSheet = false
    @State private var editingPeriod: QuietHoursPeriod?

    private let store = QuietHoursStore.shared

    var body: some View {
        List {
            if periods.isEmpty {
                Section {
                    VStack(spacing: 14) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text("非カウント時間が未設定です")
                            .font(.subheadline.weight(.medium))
                        Text("就寝や学校など、見守り判定を\n一時停止する時間帯を設定できます")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .listRowBackground(Color.clear)
                }
            }

            if !periods.isEmpty {
                Section {
                    ForEach(periods) { period in
                        Button {
                            editingPeriod = period
                        } label: {
                            QuietHoursRow(period: period, accentHex: personColorHex)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                withAnimation {
                                    store.deletePeriod(id: period.id, for: personId)
                                    periods = store.periods(for: personId)
                                }
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("設定済みの時間帯")
                }
            }

            Section {
                Button {
                    showAddSheet = true
                } label: {
                    Label("時間帯を追加", systemImage: "plus.circle.fill")
                }

                Menu {
                    Button {
                        addPreset(.sleepPreset)
                    } label: {
                        Label("就寝時間（22:00〜7:00）", systemImage: "moon.zzz.fill")
                    }
                    Button {
                        addPreset(.schoolPreset)
                    } label: {
                        Label("学校（8:00〜15:30 平日）", systemImage: "building.columns.fill")
                    }
                    Button {
                        addPreset(.workPreset)
                    } label: {
                        Label("仕事（9:00〜18:00 平日）", systemImage: "briefcase.fill")
                    }
                } label: {
                    Label("プリセットから追加", systemImage: "sparkles")
                }
            } header: {
                Text("追加")
            }
        }
        .navigationTitle("非カウント時間")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            periods = store.periods(for: personId)
        }
        .sheet(isPresented: $showAddSheet) {
            periods = store.periods(for: personId)
        } content: {
            QuietHoursPeriodEditor(personId: personId, period: nil)
        }
        .sheet(item: $editingPeriod) {
            periods = store.periods(for: personId)
        } content: { period in
            QuietHoursPeriodEditor(personId: personId, period: period)
        }
    }

    private func addPreset(_ preset: QuietHoursPeriod) {
        withAnimation {
            store.addPeriod(preset, for: personId)
            periods = store.periods(for: personId)
        }
    }
}
