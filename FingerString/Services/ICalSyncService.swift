import Foundation
import SwiftData
import Combine

@MainActor
final class ICalSyncService: ObservableObject {
    static let shared = ICalSyncService()

    @Published var isSyncing = false
    @Published var lastError: String?

    private init() {}

    func syncAllSources(in context: ModelContext) async {
        let descriptor = FetchDescriptor<ICalSource>(
            predicate: #Predicate { $0.isEnabled == true }
        )

        do {
            let sources = try context.fetch(descriptor)
            for source in sources {
                await syncSource(source, in: context)
            }
        } catch {
            lastError = "Failed to fetch iCal sources: \(error.localizedDescription)"
        }
    }

    func syncSource(_ source: ICalSource, in context: ModelContext) async {
        guard source.isEnabled else { return }

        isSyncing = true
        defer { isSyncing = false }

        do {
            let icalString = try await fetchICalData(from: source.url)
            let events = ICalParser.shared.parse(icalString)

            await processEvents(events, from: source, in: context)

            source.lastSyncedAt = Date()
            try? context.save()
        } catch {
            lastError = "Failed to sync \(source.name): \(error.localizedDescription)"
        }
    }

    private func fetchICalData(from url: URL) async throws -> String {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ICalSyncError.invalidResponse
        }

        guard let string = String(data: data, encoding: .utf8) else {
            throw ICalSyncError.invalidData
        }

        return string
    }

    private func processEvents(_ events: [ICalEvent], from source: ICalSource, in context: ModelContext) async {
        // Get the default escalation path
        let pathDescriptor = FetchDescriptor<EscalationPath>(
            predicate: #Predicate { $0.name == "Standard" }
        )
        let defaultPath = try? context.fetch(pathDescriptor).first

        for event in events {
            // Skip if this event is in the ignored list (user edited it locally)
            if source.shouldIgnoreEvent(event.uid) {
                continue
            }

            // Check if we already have this event
            let eventUid = event.uid
            let existingDescriptor = FetchDescriptor<Reminder>(
                predicate: #Predicate<Reminder> { reminder in
                    reminder.originalICalEventId == eventUid
                }
            )

            let existingReminders = try? context.fetch(existingDescriptor)

            if let existing = existingReminders?.first {
                // Update existing reminder
                updateReminder(existing, from: event)
            } else {
                // Create new reminder
                let reminder = createReminder(from: event, source: source, defaultPath: defaultPath)
                context.insert(reminder)

                // Schedule escalation if in the future
                if reminder.triggerDate > Date() {
                    EscalationEngine.shared.scheduleEscalation(for: reminder, in: context)
                }
            }
        }

        try? context.save()
    }

    private func createReminder(from event: ICalEvent, source: ICalSource, defaultPath: EscalationPath?) -> Reminder {
        let hasTime = Calendar.current.dateComponents([.hour, .minute], from: event.dtstart).hour != 0
            || Calendar.current.dateComponents([.hour, .minute], from: event.dtstart).minute != 0

        return Reminder(
            title: event.summary,
            descriptionText: event.description,
            reminderDate: event.dtstart,
            reminderTime: hasTime ? event.dtstart : nil,
            recurrenceRule: event.rrule,
            escalationPath: defaultPath,
            sourceType: .iCal,
            originalICalEventId: event.uid,
            iCalSourceId: source.id
        )
    }

    private func updateReminder(_ reminder: Reminder, from event: ICalEvent) {
        // Don't update if the user has made local edits
        if reminder.sourceType == .local {
            return
        }

        reminder.title = event.summary
        reminder.descriptionText = event.description
        reminder.reminderDate = event.dtstart

        let hasTime = Calendar.current.dateComponents([.hour, .minute], from: event.dtstart).hour != 0
            || Calendar.current.dateComponents([.hour, .minute], from: event.dtstart).minute != 0
        reminder.reminderTime = hasTime ? event.dtstart : nil

        reminder.recurrenceRule = event.rrule
        reminder.updatedAt = Date()
    }
}

enum ICalSyncError: LocalizedError {
    case invalidResponse
    case invalidData

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidData:
            return "Could not parse calendar data"
        }
    }
}
