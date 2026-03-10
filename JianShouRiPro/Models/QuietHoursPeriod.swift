import Foundation

nonisolated struct QuietHoursPeriod: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    var label: String
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    var isEnabled: Bool
    var weekdays: Set<Int>

    init(
        id: UUID = UUID(),
        label: String = "",
        startHour: Int = 22,
        startMinute: Int = 0,
        endHour: Int = 7,
        endMinute: Int = 0,
        isEnabled: Bool = true,
        weekdays: Set<Int> = Set(1...7)
    ) {
        self.id = id
        self.label = label
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.isEnabled = isEnabled
        self.weekdays = weekdays
    }

    var startTimeString: String {
        String(format: "%02d:%02d", startHour, startMinute)
    }

    var endTimeString: String {
        String(format: "%02d:%02d", endHour, endMinute)
    }

    func isActiveNow(date: Date = Date()) -> Bool {
        guard isEnabled else { return false }

        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let currentMinutes = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute

        if startMinutes <= endMinutes {
            guard weekdays.contains(weekday) else { return false }
            return currentMinutes >= startMinutes && currentMinutes < endMinutes
        } else {
            if currentMinutes >= startMinutes {
                guard weekdays.contains(weekday) else { return false }
                return true
            } else if currentMinutes < endMinutes {
                let previousDay = calendar.date(byAdding: .day, value: -1, to: date)
                let previousWeekday = previousDay.map { calendar.component(.weekday, from: $0) } ?? weekday
                guard weekdays.contains(previousWeekday) else { return false }
                return true
            }
            return false
        }
    }

    static let weekdaySymbols: [(id: Int, short: String)] = [
        (2, "月"), (3, "火"), (4, "水"), (5, "木"), (6, "金"), (7, "土"), (1, "日")
    ]

    static let sleepPreset = QuietHoursPeriod(
        label: "就寝時間",
        startHour: 22,
        startMinute: 0,
        endHour: 7,
        endMinute: 0,
        weekdays: Set(1...7)
    )

    static let schoolPreset = QuietHoursPeriod(
        label: "学校",
        startHour: 8,
        startMinute: 0,
        endHour: 15,
        endMinute: 30,
        weekdays: Set([2, 3, 4, 5, 6])
    )

    static let workPreset = QuietHoursPeriod(
        label: "仕事",
        startHour: 9,
        startMinute: 0,
        endHour: 18,
        endMinute: 0,
        weekdays: Set([2, 3, 4, 5, 6])
    )
}
