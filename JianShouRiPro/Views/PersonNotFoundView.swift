import SwiftUI

struct PersonNotFoundView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "person.slash.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("見守り対象が見つかりません")
                .font(.title3.bold())
            Text("この見守り対象は削除された可能性があります。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                dismiss()
            } label: {
                Text("戻る")
                    .fontWeight(.semibold)
                    .frame(minWidth: 120)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
            Spacer()
        }
        .padding(.horizontal)
    }
}
