import SwiftUI

struct QuietHoursRow: View {
    let period: QuietHoursPeriod
    let accentHex: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(period.isEnabled ? Color(hex: accentHex).opacity(0.15) : Color(.systemGray5))
                    .frame(width: 40, height: 40)
                Image(systemName: iconForLabel(period.label))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(period.isEnabled ? Color(hex: accentHex) : .secondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(period.label.isEmpty ? "無題" : period.label)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    if !period.isEnabled {
                        Text("無効")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color(.systemGray5), in: Capsule())
                    }
                }
                HStack(spacing: 4) {
                    Text("\(period.startTimeString) 〜 \(period.endTimeString)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text("・")
                        .foregroundStyle(.quaternary)
                    Text(weekdaySummary(period.weekdays))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.quaternary)
        }
        .contentShape(Rectangle())
    }

    private func iconForLabel(_ label: String) -> String {
        if label.contains("寝") || label.contains("睡眠") { return "moon.zzz.fill" }
        if label.contains("学校") || label.contains("授業") { return "building.columns.fill" }
        if label.contains("仕事") || label.contains("勤務") { return "briefcase.fill" }
        if label.contains("習い事") || label.contains("塾") { return "book.fill" }
        return "clock.fill"
    }

    private func weekdaySummary(_ days: Set<Int>) -> String {
        if days.count == 7 { return "毎日" }
        if days == Set([2, 3, 4, 5, 6]) { return "平日" }
        if days == Set([1, 7]) { return "週末" }
        let ordered = QuietHoursPeriod.weekdaySymbols.filter { days.contains($0.id) }
        return ordered.map(\.short).joined(separator: ",")
    }
}
