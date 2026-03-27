import SwiftUI

struct PairingInputView: View {
    let appModeManager: AppModeManager
    var watchOverViewModel: WatchOverViewModel?
    var personName: String?
    var personRelationship: Relationship?
    var personAge: Int?
    var personNotes: String?
    var personColorHex: String?
    @Binding var pairingCompleted: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pairingRepository) private var pairingRepo

    @State private var codeDigits: [String] = Array(repeating: "", count: 6)
    @State private var isValidating = false
    @State private var errorMessage: String?
    @State private var isPaired = false
    @State private var pairedPersonName: String?
    @FocusState private var focusedIndex: Int?

    private var fullCode: String {
        codeDigits.joined()
    }

    private var isCodeComplete: Bool {
        fullCode.count == 6 && fullCode.allSatisfy(\.isNumber)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer().frame(height: 20)

                VStack(spacing: 12) {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.teal)

                    Text("招待コードを入力")
                        .font(.title2.bold())

                    Text("見守られる側から受け取った\n6桁のコードを入力してください")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 8) {
                    ForEach(0..<6, id: \.self) { index in
                        TextField("", text: $codeDigits[index])
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(.title.bold().monospacedDigit())
                            .frame(width: 48, height: 60)
                            .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 12))
                            .focused($focusedIndex, equals: index)
                            .onChange(of: codeDigits[index]) { _, newValue in
                                handleDigitChange(at: index, newValue: newValue)
                            }
                    }
                }

                if let errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle.fill")
                        Text(errorMessage)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.red)
                }

                if isPaired, let name = pairedPersonName {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("\(name)さんの見守りを開始しました！")
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                    }
                    .font(.headline)
                }

                Button {
                    Task { await validateAndPair() }
                } label: {
                    if isValidating {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    } else {
                        Text("見守りを開始")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .disabled(!isCodeComplete || isValidating || isPaired)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.horizontal)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .onAppear {
                focusedIndex = 0
            }
        }
    }

    private func handleDigitChange(at index: Int, newValue: String) {
        let digits = String(newValue.filter(\.isNumber))

        if digits.count > 1 {
            let chars = Array(digits.prefix(6 - index))
            for (offset, char) in chars.enumerated() {
                let targetIndex = index + offset
                guard targetIndex < 6 else { break }
                codeDigits[targetIndex] = String(char)
            }
            let nextIndex = min(index + chars.count, 5)
            focusedIndex = codeDigits[nextIndex].isEmpty ? nextIndex : nil
            return
        }

        let filtered = String(digits.prefix(1))
        if codeDigits[index] != filtered {
            codeDigits[index] = filtered
        }
        if !filtered.isEmpty && index < 5 {
            focusedIndex = index + 1
        }
    }

    private func validateAndPair() async {
        isValidating = true
        errorMessage = nil

        do {
            let member = try await pairingRepo.consumePairingCode(
                code: fullCode,
                displayName: personName,
                relationship: personRelationship?.rawValue,
                age: personAge,
                colorHex: personColorHex,
                notes: personNotes
            )

            if let name = personName {
                pairedPersonName = name
            } else {
                pairedPersonName = member.displayName
            }

            appModeManager.familyId = member.familyId

            if let viewModel = watchOverViewModel {
                viewModel.familyId = member.familyId
                await viewModel.loadData()
            }

            isPaired = true
            pairingCompleted = true
            isValidating = false

            try? await Task.sleep(for: .seconds(1.5))
            dismiss()
        } catch {
            errorMessage = "ペアリングに失敗しました: \(error.localizedDescription)"
            isValidating = false
        }
    }
}
