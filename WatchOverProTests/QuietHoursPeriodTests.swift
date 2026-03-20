import Testing
import Foundation
@testable import WatchOverPro

struct QuietHoursPeriodTests {
    // MARK: - Helper

    /// Creates a Date for the given weekday/hour/minute using a fixed calendar.
    /// weekday: 1=Sunday, 2=Monday, ... 7=Saturday
    private func makeDate(weekday: Int, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        // March 2026: Sun=1, Mon=2, ..., Sat=7
        // March 1, 2026 is a Sunday
        components.day = 1 + (weekday - 1)  // day 1=Sun, 2=Mon, ... 7=Sat
        components.hour = hour
        components.minute = minute
        components.second = 0
        return Calendar.current.date(from: components)!
    }

    // MARK: - Same-day period (8:00 - 15:30)

    @Test func sameDayPeriod_insideRange_returnsTrue() {
        let period = QuietHoursPeriod(
            label: "学校",
            startHour: 8, startMinute: 0,
            endHour: 15, endMinute: 30,
            weekdays: Set(1...7)
        )
        let date = makeDate(weekday: 2, hour: 10, minute: 0) // Monday 10:00
        #expect(period.isActiveNow(date: date) == true)
    }

    @Test func sameDayPeriod_outsideRange_returnsFalse() {
        let period = QuietHoursPeriod(
            label: "学校",
            startHour: 8, startMinute: 0,
            endHour: 15, endMinute: 30,
            weekdays: Set(1...7)
        )
        let date = makeDate(weekday: 2, hour: 16, minute: 0) // Monday 16:00
        #expect(period.isActiveNow(date: date) == false)
    }

    @Test func sameDayPeriod_beforeStart_returnsFalse() {
        let period = QuietHoursPeriod(
            label: "学校",
            startHour: 8, startMinute: 0,
            endHour: 15, endMinute: 30,
            weekdays: Set(1...7)
        )
        let date = makeDate(weekday: 2, hour: 7, minute: 59) // Monday 07:59
        #expect(period.isActiveNow(date: date) == false)
    }

    // MARK: - Overnight period (22:00 - 7:00)

    @Test func overnightPeriod_lateNight_returnsTrue() {
        let period = QuietHoursPeriod(
            label: "就寝",
            startHour: 22, startMinute: 0,
            endHour: 7, endMinute: 0,
            weekdays: Set(1...7)
        )
        let date = makeDate(weekday: 2, hour: 23, minute: 0) // Monday 23:00
        #expect(period.isActiveNow(date: date) == true)
    }

    @Test func overnightPeriod_earlyMorning_returnsTrue() {
        let period = QuietHoursPeriod(
            label: "就寝",
            startHour: 22, startMinute: 0,
            endHour: 7, endMinute: 0,
            weekdays: Set(1...7)
        )
        let date = makeDate(weekday: 3, hour: 5, minute: 0) // Tuesday 05:00
        #expect(period.isActiveNow(date: date) == true)
    }

    @Test func overnightPeriod_midDay_returnsFalse() {
        let period = QuietHoursPeriod(
            label: "就寝",
            startHour: 22, startMinute: 0,
            endHour: 7, endMinute: 0,
            weekdays: Set(1...7)
        )
        let date = makeDate(weekday: 2, hour: 12, minute: 0) // Monday 12:00
        #expect(period.isActiveNow(date: date) == false)
    }

    // MARK: - Disabled period

    @Test func disabledPeriod_returnsFalse() {
        let period = QuietHoursPeriod(
            label: "無効",
            startHour: 0, startMinute: 0,
            endHour: 23, endMinute: 59,
            isEnabled: false,
            weekdays: Set(1...7)
        )
        let date = makeDate(weekday: 2, hour: 12, minute: 0)
        #expect(period.isActiveNow(date: date) == false)
    }

    // MARK: - Weekday filter

    @Test func weekdayFilter_matchingDay_returnsTrue() {
        // Weekdays only (Mon=2 through Fri=6)
        let period = QuietHoursPeriod(
            label: "仕事",
            startHour: 9, startMinute: 0,
            endHour: 18, endMinute: 0,
            weekdays: Set([2, 3, 4, 5, 6])
        )
        let date = makeDate(weekday: 3, hour: 12, minute: 0) // Tuesday 12:00
        #expect(period.isActiveNow(date: date) == true)
    }

    @Test func weekdayFilter_nonMatchingDay_returnsFalse() {
        // Weekdays only (Mon=2 through Fri=6)
        let period = QuietHoursPeriod(
            label: "仕事",
            startHour: 9, startMinute: 0,
            endHour: 18, endMinute: 0,
            weekdays: Set([2, 3, 4, 5, 6])
        )
        let date = makeDate(weekday: 1, hour: 12, minute: 0) // Sunday 12:00
        #expect(period.isActiveNow(date: date) == false)
    }

    // MARK: - Time string formatting

    @Test func startTimeString_formatsCorrectly() {
        let period = QuietHoursPeriod(startHour: 8, startMinute: 5, endHour: 15, endMinute: 30)
        #expect(period.startTimeString == "08:05")
    }

    @Test func endTimeString_formatsCorrectly() {
        let period = QuietHoursPeriod(startHour: 8, startMinute: 0, endHour: 7, endMinute: 0)
        #expect(period.endTimeString == "07:00")
    }

    // MARK: - Presets

    @Test func sleepPreset_hasExpectedValues() {
        let preset = QuietHoursPeriod.sleepPreset
        #expect(preset.label == "就寝時間")
        #expect(preset.startHour == 22)
        #expect(preset.startMinute == 0)
        #expect(preset.endHour == 7)
        #expect(preset.endMinute == 0)
        #expect(preset.weekdays == Set(1...7))
        #expect(preset.isEnabled == true)
    }

    @Test func schoolPreset_hasExpectedValues() {
        let preset = QuietHoursPeriod.schoolPreset
        #expect(preset.label == "学校")
        #expect(preset.startHour == 8)
        #expect(preset.endHour == 15)
        #expect(preset.endMinute == 30)
        #expect(preset.weekdays == Set([2, 3, 4, 5, 6]))
    }

    @Test func workPreset_hasExpectedValues() {
        let preset = QuietHoursPeriod.workPreset
        #expect(preset.label == "仕事")
        #expect(preset.startHour == 9)
        #expect(preset.endHour == 18)
        #expect(preset.weekdays == Set([2, 3, 4, 5, 6]))
    }
}
