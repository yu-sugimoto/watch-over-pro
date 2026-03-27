import SwiftUI

struct PersonNotFoundView: View {
    var body: some View {
        ContentUnavailableView(
            "見守り対象が見つかりません",
            systemImage: "person.crop.circle.badge.questionmark",
            description: Text("この見守り対象は削除された可能性があります。")
        )
    }
}
