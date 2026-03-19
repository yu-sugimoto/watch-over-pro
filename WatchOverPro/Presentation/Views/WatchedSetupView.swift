import SwiftUI

struct WatchedSetupView: View {
    let appModeManager: AppModeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pairingRepository) private var pairingRepo
    @Environment(\.authRepository) private var authRepo

    @State private var isGenerating = false
    @State private var generatedCode: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            if let code = generatedCode {
                codeResultView(code: code)
            } else {
                generateView
            }
        }
    }

    private var generateView: some View {
        VStack(spacing: 28) {
            Spacer().frame(height: 24)

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(.teal.opacity(0.15))
                        .frame(width: 80, height: 80)
                    Image(systemName: "key.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.teal)
                }

                Text("招待コードを発行")
                    .font(.title2.bold())

                Text("見守る側のアプリでこのコードを入力すると\nあなたの位置情報が共有されます")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 10))
                .padding(.horizontal)
            }

            Button {
                Task { await generateCode() }
            } label: {
                if isGenerating {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "key.fill")
                        Text("コードを発行する")
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
            .disabled(isGenerating)
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 12) {
                Text("ペアリング手順")
                    .font(.headline)

                PairingStepRow(number: 1, text: "下のボタンでコードを発行")
                PairingStepRow(number: 2, text: "見守る方のiPhoneにアプリをインストール")
                PairingStepRow(number: 3, text: "「見守る側」を選択し、見守り対象を登録")
                PairingStepRow(number: 4, text: "登録時に招待コードを入力して完了")
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
            .padding(.horizontal)

            Spacer()
        }
        .navigationTitle("見守られる側の設定")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { dismiss() }
            }
        }
    }

    private func codeResultView(code: String) -> some View {
        VStack(spacing: 28) {
            Spacer().frame(height: 16)

            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(.teal.opacity(0.15))
                        .frame(width: 72, height: 72)
                    Image(systemName: "key.fill")
                        .font(.title)
                        .foregroundStyle(.teal)
                }

                Text("招待コードを発行しました")
                    .font(.title3.bold())

                Text("見守る側のアプリで\nこのコードを入力してもらってください")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    ForEach(Array(code.enumerated()), id: \.offset) { _, char in
                        Text(String(char))
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .frame(width: 48, height: 64)
                            .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 12))
                    }
                }

                Button {
                    UIPasteboard.general.string = code
                } label: {
                    Label("コードをコピー", systemImage: "doc.on.doc")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.bordered)
                .tint(.teal)

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                    Text("有効期限: 24時間")
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("ペアリング手順")
                    .font(.headline)

                PairingStepRow(number: 1, text: "見守る方のiPhoneにアプリをインストール")
                PairingStepRow(number: 2, text: "アプリ起動時に「見守る側」を選択")
                PairingStepRow(number: 3, text: "「＋」から見守り対象を登録し招待コードを入力")
                PairingStepRow(number: 4, text: "位置情報が自動的に同期されます")
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
            .padding(.horizontal)

            Spacer()

            Button {
                completeSetup()
            } label: {
                Text("見守りモードを開始")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .navigationTitle("招待コード")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完了") { completeSetup() }
            }
        }
    }

    private func generateCode() async {
        isGenerating = true
        errorMessage = nil

        do {
            guard let userId = await authRepo.currentUserId else {
                errorMessage = "ユーザー認証情報を取得できませんでした"
                isGenerating = false
                return
            }
            let familyId = appModeManager.familyId ?? UUID().uuidString
            let pairingCode = try await pairingRepo.createPairingCode(familyId: familyId)
            appModeManager.linkToTrackedUser(id: userId, name: "", familyId: familyId)
            generatedCode = pairingCode.code
        } catch {
            errorMessage = "コード生成に失敗しました: \(error.localizedDescription)"
        }

        isGenerating = false
    }

    private func completeSetup() {
        appModeManager.setMode(.watched)
        dismiss()
    }
}
