import Foundation

enum SnoozeOption: Identifiable, CaseIterable {
    case oneHour
    case threeHours
    case untilEvening   // 5:00 PM
    case untilTomorrow  // 9:00 AM next day

    var id: String { displayName }

    var displayName: String {
        switch self {
        case .oneHour: return "1 hour"
        case .threeHours: return "3 hours"
        case .untilEvening: return "Until 5:00 PM"
        case .untilTomorrow: return "Until tomorrow 9:00 AM"
        }
    }

    func snoozeDate(from now: Date = Date()) -> Date {
        let calendar = Calendar.current

        switch self {
        case .oneHour:
            return calendar.date(byAdding: .hour, value: 1, to: now) ?? now

        case .threeHours:
            return calendar.date(byAdding: .hour, value: 3, to: now) ?? now

        case .untilEvening:
            // 5:00 PM today, or tomorrow if already past 5 PM
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = 17
            components.minute = 0

            if let evening = calendar.date(from: components), evening > now {
                return evening
            } else {
                // It's already past 5 PM, use tomorrow
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
                components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
                components.hour = 17
                components.minute = 0
                return calendar.date(from: components) ?? now
            }

        case .untilTomorrow:
            // 9:00 AM tomorrow
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
            components.hour = 9
            components.minute = 0
            return calendar.date(from: components) ?? now
        }
    }
}
