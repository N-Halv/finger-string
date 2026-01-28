import Foundation

final class ICalSerializer {
    static let shared = ICalSerializer()

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    private let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    private init() {}

    func serialize(reminder: Reminder) -> String {
        var lines: [String] = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//Finger String//Finger String iOS//EN",
            "BEGIN:VEVENT",
            "UID:\(reminder.id.uuidString)",
            "DTSTAMP:\(dateFormatter.string(from: Date()))",
            "SUMMARY:\(escapeICalString(reminder.title))"
        ]

        // DTSTART
        if reminder.reminderTime != nil {
            lines.append("DTSTART:\(dateFormatter.string(from: reminder.triggerDate))")
        } else {
            lines.append("DTSTART;VALUE=DATE:\(dateOnlyFormatter.string(from: reminder.reminderDate))")
        }

        // Description
        if let description = reminder.descriptionText {
            lines.append("DESCRIPTION:\(escapeICalString(description))")
        }

        // Recurrence rule
        if let rrule = reminder.recurrenceRule {
            lines.append("RRULE:\(rrule)")
        }

        lines.append(contentsOf: [
            "END:VEVENT",
            "END:VCALENDAR"
        ])

        return lines.joined(separator: "\r\n")
    }

    func serializeMultiple(reminders: [Reminder]) -> String {
        var lines: [String] = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//Finger String//Finger String iOS//EN"
        ]

        for reminder in reminders {
            lines.append(contentsOf: serializeEvent(reminder: reminder))
        }

        lines.append("END:VCALENDAR")

        return lines.joined(separator: "\r\n")
    }

    private func serializeEvent(reminder: Reminder) -> [String] {
        var lines: [String] = [
            "BEGIN:VEVENT",
            "UID:\(reminder.id.uuidString)",
            "DTSTAMP:\(dateFormatter.string(from: Date()))",
            "SUMMARY:\(escapeICalString(reminder.title))"
        ]

        if reminder.reminderTime != nil {
            lines.append("DTSTART:\(dateFormatter.string(from: reminder.triggerDate))")
        } else {
            lines.append("DTSTART;VALUE=DATE:\(dateOnlyFormatter.string(from: reminder.reminderDate))")
        }

        if let description = reminder.descriptionText {
            lines.append("DESCRIPTION:\(escapeICalString(description))")
        }

        if let rrule = reminder.recurrenceRule {
            lines.append("RRULE:\(rrule)")
        }

        lines.append("END:VEVENT")

        return lines
    }

    private func escapeICalString(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}
