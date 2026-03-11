import Foundation

nonisolated enum Relationship: String, Codable, Sendable, CaseIterable {
    case parent
    case grandparent
    case child
    case spouse
    case sibling
    case other

    var label: String {
        switch self {
        case .parent: "親"
        case .grandparent: "祖父母"
        case .child: "子ども"
        case .spouse: "配偶者"
        case .sibling: "兄弟姉妹"
        case .other: "その他"
        }
    }

    var icon: String {
        switch self {
        case .parent: "figure.and.child.holdinghands"
        case .grandparent: "figure.roll"
        case .child: "figure.child"
        case .spouse: "heart.fill"
        case .sibling: "person.2.fill"
        case .other: "person.fill"
        }
    }
}
