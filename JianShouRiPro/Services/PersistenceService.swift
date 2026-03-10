import Foundation

nonisolated final class PersistenceService: Sendable {
    static let shared = PersistenceService()

    private let sessionsKey = "gait_sessions"
    private let summariesKey = "gait_summaries"

    private var sessionsURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return docs.appendingPathComponent("gait_sessions.json")
    }

    private var summariesURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return docs.appendingPathComponent("gait_summaries.json")
    }

    func saveSessions(_ sessions: [GaitSession]) {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        try? data.write(to: sessionsURL, options: .atomic)
    }

    func loadSessions() -> [GaitSession] {
        guard let data = try? Data(contentsOf: sessionsURL) else { return [] }
        return (try? JSONDecoder().decode([GaitSession].self, from: data)) ?? []
    }

    func saveSummaries(_ summaries: [DailyGaitSummary]) {
        guard let data = try? JSONEncoder().encode(summaries) else { return }
        try? data.write(to: summariesURL, options: .atomic)
    }

    func loadSummaries() -> [DailyGaitSummary] {
        guard let data = try? Data(contentsOf: summariesURL) else { return [] }
        return (try? JSONDecoder().decode([DailyGaitSummary].self, from: data)) ?? []
    }
}
