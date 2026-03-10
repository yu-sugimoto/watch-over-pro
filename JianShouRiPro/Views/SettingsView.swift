import SwiftUI

struct SettingsView: View {
    let appModeManager: AppModeManager
    @State private var showModeResetConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section("アカウント") {
                    LabeledContent("モード") {
                        HStack(spacing: 6) {
                            Image(systemName: "eye.fill")
                                .foregroundStyle(.blue)
                            Text("見守る側")
                                .font(.subheadline)
                        }
                    }
                    Button("モードを変更", role: .destructive) {
                        showModeResetConfirmation = true
                    }
                }

                Section("アプリについて") {
                    LabeledContent("バージョン", value: "1.0.0")
                    LabeledContent("アプリ名", value: "見守り Pro")
                }

                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "shield.checkered")
                            .font(.largeTitle)
                            .foregroundStyle(.teal)
                        Text("見守り Pro")
                            .font(.headline)
                        Text("位置情報と歩行異常状態・非活動状態で\nご家族の安全を見守ります。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("設定")
            .confirmationDialog("モードを変更しますか？", isPresented: $showModeResetConfirmation, titleVisibility: .visible) {
                Button("モードを変更", role: .destructive) {
                    appModeManager.resetAll()
                }
            } message: {
                Text("現在の設定がリセットされ、モード選択画面に戻ります。")
            }
        }
    }
}
