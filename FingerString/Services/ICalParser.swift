import Foundation

struct ICalEvent {
    let uid: String
    let summary: String
    let description: String?
    let dtstart: Date
    let dtend: Date?
    let rrule: String?
}

final class ICalParser {
    static let shared = ICalParser()

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss"
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

    func parse(_ icalString: String) -> [ICalEvent] {
        var events: [ICalEvent] = []
        var currentEvent: [String: String]?
        var currentKey: String?
        var currentValue: String = ""

        let lines = icalString.components(separatedBy: .newlines)

        for line in lines {
            // Handle line continuation (lines starting with space or tab)
            if line.hasPrefix(" ") || line.hasPrefix("\t") {
                currentValue += line.trimmingCharacters(in: .whitespaces)
                continue
            }

            // Store previous key-value pair
            if let key = currentKey, !currentValue.isEmpty {
                currentEvent?[key] = currentValue
            }

            // Parse new line
            if line == "BEGIN:VEVENT" {
                currentEvent = [:]
                currentKey = nil
                currentValue = ""
            } else if line == "END:VEVENT" {
                if let event = currentEvent {
                    if let parsedEvent = parseEvent(from: event) {
                        events.append(parsedEvent)
                    }
                }
                currentEvent = nil
                currentKey = nil
                currentValue = ""
            } else if currentEvent != nil {
                // Parse property
                let parts = line.split(separator: ":", maxSplits: 1)
                if parts.count >= 1 {
                    // Handle parameters (e.g., DTSTART;VALUE=DATE:20240101)
                    let keyPart = String(parts[0])
                    let key = keyPart.split(separator: ";").first.map(String.init) ?? keyPart

                    currentKey = key
                    currentValue = parts.count > 1 ? String(parts[1]) : ""
                }
            }
        }

        return events
    }

    private func parseEvent(from properties: [String: String]) -> ICalEvent? {
        guard let uid = properties["UID"],
              let summary = properties["SUMMARY"],
              let dtstartStr = properties["DTSTART"] else {
            return nil
        }

        let dtstart = parseDate(dtstartStr)

        guard let startDate = dtstart else {
            return nil
        }

        let dtend: Date?
        if let dtendStr = properties["DTEND"] {
            dtend = parseDate(dtendStr)
        } else {
            dtend = nil
        }

        return ICalEvent(
            uid: uid,
            summary: unescapeICalString(summary),
            description: properties["DESCRIPTION"].map { unescapeICalString($0) },
            dtstart: startDate,
            dtend: dtend,
            rrule: properties["RRULE"]
        )
    }

    private func parseDate(_ string: String) -> Date? {
        // Remove any trailing Z for UTC
        var dateString = string
        if dateString.hasSuffix("Z") {
            dateString = String(dateString.dropLast())
        }

        // Try datetime format first
        if let date = dateFormatter.date(from: dateString) {
            return date
        }

        // Try date-only format
        if let date = dateOnlyFormatter.date(from: dateString) {
            return date
        }

        return nil
    }

    private func unescapeICalString(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }
}
