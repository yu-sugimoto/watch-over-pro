import SwiftUI

struct PersonRegistrationView: View {
    let watchOverViewModel: WatchOverViewModel
    let appModeManager: AppModeManager
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var relationship: Relationship = .parent
    @State private var age = 70
    @State private var notes = ""
    @State private var selectedColor = "34C759"
    @State private var showPairingInput = false
    @State private var pairingCompleted = false

    private let colorOptions = [
        "34C759", "007AFF", "FF9500", "AF52DE",
        "FF2D55", "5856D6", "FF6482", "30B0C7"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
                    TextField("名前", text: $name)
                        .textContentType(.name)

                    Picker("続柄", selection: $relationship) {
                        ForEach(Relationship.allCases, id: \.self) { rel in
                            Label(rel.label, systemImage: rel.icon)
                                .tag(rel)
                        }
                    }

                    Stepper("年齢: \(age)歳", value: $age, in: 1...120)
                }

                Section("テーマカラー") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(colorOptions, id: \.self) { hex in
                            Button {
                                selectedColor = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 44, height: 44)
                                    .overlay {
                                        if selectedColor == hex {
                                            Image(systemName: "checkmark")
                                                .font(.subheadline.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("メモ") {
                    TextField("持病や注意事項など", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Button {
                        showPairingInput = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("登録", systemImage: "link.circle.fill")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                } footer: {
                    Text("見守られる側から受け取った招待コードを次の画面で入力します")
                        .font(.caption)
                }
            }
            .navigationTitle("見守り対象を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showPairingInput, onDismiss: {
                if pairingCompleted {
                    dismiss()
                }
            }) {
                PairingInputView(
                    appModeManager: appModeManager,
                    watchOverViewModel: watchOverViewModel,
                    personName: name.trimmingCharacters(in: .whitespaces),
                    personRelationship: relationship,
                    personAge: age,
                    personNotes: notes,
                    personColorHex: selectedColor,
                    pairingCompleted: $pairingCompleted
                )
            }
        }
    }
}
