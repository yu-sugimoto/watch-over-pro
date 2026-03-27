import SwiftUI

struct PairingCodeGeneratorView: View {
    let familyId: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pairingRepository) private var pairingRepo

    @State private var generatedCode: String?
    @State private var isGenerating = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var copiedFeedback = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 8)

                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(.teal.opacity(0.15))
                                .frame(width: 72, height: 72)
                            Image(systemName: "key.fill")
                                .font(.title)
                                .foregroundStyle(.teal)
                        }

                        Text("招待コード")
                            .font(.title3.bold())

                        Text("見守る側のアプリで\nこのコードを入力してもらってください")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    if isLoading {
                        ProgressView()
                            .frame(height: 80)
                    } else if let code = generatedCode {
                        codeDisplaySection(code)
                    } else {
                        generateSection
                    }

                    stepsCard

                    Spacer()
                }
                .padding(.horizontal)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func codeDisplaySection(_ code: String) -> some View {
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
                copiedFeedback = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    copiedFeedback = false
                }
            } label: {
                Label(copiedFeedback ? "コピーしました" : "コードをコピー", systemImage: copiedFeedback ? "checkmark" : "doc.on.doc")
                    .font(.subheadline.weight(.medium))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.bordered)
            .tint(copiedFeedback ? .green : .teal)
            .sensoryFeedback(.success, trigger: copiedFeedback)

            HStack(spacing: 6) {
                Image(systemName: "clock")
                Text("有効期限: 24時間")
            }
            .font(.caption)
            .foregroundStyle(.tertiary)

            Text("同じコードを複数の見守り者が使用できます")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                Task { await generateCode() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("再発行")
                }
                .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .tint(.teal)
            .disabled(isGenerating)
        }
    }

    private var generateSection: some View {
        VStack(spacing: 12) {
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
                        Text("招待コードを生成")
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
            .disabled(isGenerating)
        }
    }

    private var stepsCard: some View {
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
    }

    private func generateCode() async {
        isGenerating = true
        errorMessage = nil
        do {
            let pairingCode = try await pairingRepo.createPairingCode(familyId: familyId)
            generatedCode = pairingCode.code
        } catch {
            errorMessage = "コード生成に失敗しました: \(error.localizedDescription)"
        }
        isGenerating = false
    }
}
