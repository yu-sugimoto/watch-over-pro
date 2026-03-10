import SwiftUI

struct PairingCodeGeneratorView: View {
    let personId: UUID
    let deviceId: String
    @Environment(\.dismiss) private var dismiss

    @State private var generatedCode: String?
    @State private var isGenerating = false
    @State private var existingCode: String?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var connectedWatcherCount = 0
    @State private var showInvalidateConfirmation = false
    @State private var copiedFeedback = false

    private let pairingRepo = PairingRepository.shared

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

                    if connectedWatcherCount > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "person.2.fill")
                                .foregroundStyle(.teal)
                            Text("現在 \(connectedWatcherCount)人 が見守り中")
                                .font(.subheadline.weight(.medium))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.teal.opacity(0.1), in: Capsule())
                    }

                    if isLoading {
                        ProgressView()
                            .frame(height: 80)
                    } else if let code = generatedCode ?? existingCode {
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
            .task {
                await loadData()
            }
            .confirmationDialog("現在のコードを無効化しますか？", isPresented: $showInvalidateConfirmation, titleVisibility: .visible) {
                Button("無効化する", role: .destructive) {
                    Task {
                        await pairingRepo.invalidateAllCodes(for: personId)
                        generatedCode = nil
                        existingCode = nil
                    }
                }
            } message: {
                Text("無効化すると、このコードでは新しい見守り者を追加できなくなります。既に接続済みの見守り者には影響しません。")
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

            HStack(spacing: 12) {
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

                Button {
                    showInvalidateConfirmation = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle")
                        Text("無効化")
                    }
                    .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
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
            PairingStepRow(number: 4, text: "歩行データが自動的に同期されます")
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }

    private func loadData() async {
        isLoading = true
        async let codeResult = pairingRepo.fetchActiveCode(for: personId)
        async let countResult = pairingRepo.fetchConnectedWatcherCount(for: personId)
        let (code, count) = await (codeResult, countResult)
        existingCode = code?.code
        connectedWatcherCount = count
        isLoading = false
    }

    private func generateCode() async {
        isGenerating = true
        errorMessage = nil
        do {
            let code = try await pairingRepo.generateCode(for: personId, deviceId: deviceId)
            generatedCode = code
            existingCode = nil
        } catch {
            errorMessage = "コード生成に失敗しました: \(error.localizedDescription)"
        }
        isGenerating = false
    }
}
