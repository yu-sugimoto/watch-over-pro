import Foundation

@Observable
@MainActor
final class QuietHoursStore {
    static let shared = QuietHoursStore()

    private var cache: [String: [QuietHoursPeriod]] = [:]

    private init() {}

    func periods(for personId: String) -> [QuietHoursPeriod] {
        if let cached = cache[personId] {
            return cached
        }
        let loaded = load(personId: personId)
        cache[personId] = loaded
        return loaded
    }

    func savePeriods(_ periods: [QuietHoursPeriod], for personId: String) {
        cache[personId] = periods
        guard let data = try? JSONEncoder().encode(periods) else { return }
        try? data.write(to: fileURL(for: personId), options: .atomic)
    }

    func addPeriod(_ period: QuietHoursPeriod, for personId: String) {
        var list = periods(for: personId)
        list.append(period)
        savePeriods(list, for: personId)
    }

    func updatePeriod(_ period: QuietHoursPeriod, for personId: String) {
        var list = periods(for: personId)
        if let index = list.firstIndex(where: { $0.id == period.id }) {
            list[index] = period
            savePeriods(list, for: personId)
        }
    }

    func deletePeriod(id: UUID, for personId: String) {
        var list = periods(for: personId)
        list.removeAll { $0.id == id }
        savePeriods(list, for: personId)
    }

    func isInQuietHours(for personId: String, date: Date = Date()) -> Bool {
        periods(for: personId).contains { $0.isActiveNow(date: date) }
    }

    func activeQuietPeriod(for personId: String, date: Date = Date()) -> QuietHoursPeriod? {
        periods(for: personId).first { $0.isActiveNow(date: date) }
    }

    private func load(personId: String) -> [QuietHoursPeriod] {
        let url = fileURL(for: personId)
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([QuietHoursPeriod].self, from: data)) ?? []
    }

    private func fileURL(for personId: String) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return docs.appendingPathComponent("quiet_hours_\(personId).json")
    }
}
