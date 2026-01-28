import Foundation
import SwiftData

@Model
final class Reminder {
    var id: UUID
    var title: String
    var descriptionText: String?
    var reminderDate: Date
    var reminderTime: Date?  // Optional time component
    var recurrenceRule: String?  // iCal RRULE format

    var stateRaw: String
    var state: ReminderState {
        get { ReminderState(rawValue: stateRaw) ?? .pending }
        set { stateRaw = newValue.rawValue }
    }

    var escalationPath: EscalationPath?
    var currentEscalationStep: Int  // Track position for snooze resume
    var snoozedUntil: Date?

    var sourceTypeRaw: String
    var sourceType: SourceType {
        get { SourceType(rawValue: sourceTypeRaw) ?? .local }
        set { sourceTypeRaw = newValue.rawValue }
    }

    var originalICalEventId: String?  // For overridden iCal events
    var iCalSourceId: UUID?  // Reference to ICalSource

    var createdAt: Date
    var updatedAt: Date

    // Computed: combine date and time
    var triggerDate: Date {
        guard let time = reminderTime else { return reminderDate }
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: reminderDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute

        return calendar.date(from: combined) ?? reminderDate
    }

    var isActive: Bool {
        state == .active
    }

    var isPending: Bool {
        state == .pending
    }

    var isClosed: Bool {
        state == .completed || state == .ignored
    }

    init(
        id: UUID = UUID(),
        title: String,
        descriptionText: String? = nil,
        reminderDate: Date,
        reminderTime: Date? = nil,
        recurrenceRule: String? = nil,
        escalationPath: EscalationPath? = nil,
        sourceType: SourceType = .local,
        originalICalEventId: String? = nil,
        iCalSourceId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.descriptionText = descriptionText
        self.reminderDate = reminderDate
        self.reminderTime = reminderTime
        self.recurrenceRule = recurrenceRule
        self.stateRaw = ReminderState.pending.rawValue
        self.escalationPath = escalationPath
        self.currentEscalationStep = 0
        self.snoozedUntil = nil
        self.sourceTypeRaw = sourceType.rawValue
        self.originalICalEventId = originalICalEventId
        self.iCalSourceId = iCalSourceId
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    func markComplete() {
        state = .completed
        snoozedUntil = nil
        updatedAt = Date()
    }

    func markIgnored() {
        state = .ignored
        snoozedUntil = nil
        updatedAt = Date()
    }

    func activate() {
        state = .active
        currentEscalationStep = 0
        updatedAt = Date()
    }

    func snooze(until date: Date) {
        snoozedUntil = date
        updatedAt = Date()
    }

    func resumeFromSnooze() {
        snoozedUntil = nil
        updatedAt = Date()
        // Note: currentEscalationStep stays the same to resume from same step
    }

    func advanceEscalationStep() {
        currentEscalationStep += 1
        updatedAt = Date()
    }
}
