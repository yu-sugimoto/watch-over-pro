import Foundation

nonisolated enum AppMode: String, Codable, Sendable {
    case none
    case watcher
    case watched
}
