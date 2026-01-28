import Foundation
import SwiftData
import Combine

@MainActor
final class EscalationEngine: ObservableObject {
    static let shared = EscalationEngine()

    private let notificationManager = NotificationManager.shared
    private var notificationObserver: NSObjectProtocol?

    private init() {
        setupNotificationObserver()
    }

    private func setupNotificationObserver() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .reminderNotificationReceived,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let engine = self,
                  let userInfo = notification.userInfo,
                  let reminderId = userInfo["reminderId"] as? UUID,
                  let stepIndex = userInfo["stepIndex"] as? Int,
                  let actionIdentifier = userInfo["actionIdentifier"] as? String else {
                return
            }
            Task { @MainActor in
                engine.handleNotificationResponse(
                    reminderId: reminderId,
                    stepIndex: stepIndex,
                    actionIdentifier: actionIdentifier
                )
            }
        }
    }

    // MARK: - Escalation Scheduling

    func scheduleEscalation(for reminder: Reminder, in context: ModelContext) {
        guard let path = reminder.escalationPath else { return }

        // Cancel any existing notifications
        notificationManager.cancelNotifications(for: reminder)

        let steps = path.steps
        let baseDate = reminder.triggerDate

        for (index, step) in steps.enumerated() {
            // Skip steps before current position (for snooze resume)
            if index < reminder.currentEscalationStep {
                continue
            }

            let stepDate = Calendar.current.date(
                byAdding: .minute,
                value: step.delayMinutes,
                to: baseDate
            ) ?? baseDate

            // Only schedule future notifications
            guard stepDate > Date() else { continue }

            if let repeatInterval = step.repeatInterval {
                // This is a repeating step
                notificationManager.scheduleRepeatingNotifications(
                    for: reminder,
                    startingAt: stepDate,
                    stepIndex: index,
                    intervalMinutes: repeatInterval
                )
            } else {
                // Single notification
                notificationManager.scheduleNotification(
                    for: reminder,
                    at: stepDate,
                    stepIndex: index,
                    isAlarm: step.type == .alarm
                )
            }
        }

        // Activate the reminder
        reminder.activate()
        try? context.save()
    }

    func scheduleEscalationFromSnooze(for reminder: Reminder, resumeAt: Date, in context: ModelContext) {
        guard let path = reminder.escalationPath else { return }

        // Cancel any existing notifications
        notificationManager.cancelNotifications(for: reminder)

        let steps = path.steps
        let currentStep = reminder.currentEscalationStep

        for (index, step) in steps.enumerated() {
            // Start from current step
            if index < currentStep {
                continue
            }

            let stepDate: Date
            if index == currentStep {
                // Resume immediately at snooze end
                stepDate = resumeAt
            } else {
                // Calculate delay from previous steps
                let delayFromCurrentStep = step.delayMinutes - (steps[currentStep].delayMinutes)
                stepDate = Calendar.current.date(
                    byAdding: .minute,
                    value: delayFromCurrentStep,
                    to: resumeAt
                ) ?? resumeAt
            }

            // Only schedule future notifications
            guard stepDate > Date() else { continue }

            if let repeatInterval = step.repeatInterval {
                notificationManager.scheduleRepeatingNotifications(
                    for: reminder,
                    startingAt: stepDate,
                    stepIndex: index,
                    intervalMinutes: repeatInterval
                )
            } else {
                notificationManager.scheduleNotification(
                    for: reminder,
                    at: stepDate,
                    stepIndex: index,
                    isAlarm: step.type == .alarm
                )
            }
        }

        reminder.resumeFromSnooze()
        try? context.save()
    }

    func cancelEscalation(for reminder: Reminder, in context: ModelContext) {
        notificationManager.cancelNotifications(for: reminder)
        try? context.save()
    }

    // MARK: - Actions

    func complete(reminder: Reminder, in context: ModelContext) {
        notificationManager.cancelNotifications(for: reminder)
        reminder.markComplete()
        try? context.save()
    }

    func ignore(reminder: Reminder, in context: ModelContext) {
        notificationManager.cancelNotifications(for: reminder)
        reminder.markIgnored()
        try? context.save()
    }

    func snooze(reminder: Reminder, option: SnoozeOption, in context: ModelContext) {
        let snoozeUntil = option.snoozeDate()
        notificationManager.cancelNotifications(for: reminder)
        reminder.snooze(until: snoozeUntil)
        try? context.save()

        // Schedule to resume escalation
        scheduleEscalationFromSnooze(for: reminder, resumeAt: snoozeUntil, in: context)
    }

    func snooze(reminder: Reminder, until date: Date, in context: ModelContext) {
        notificationManager.cancelNotifications(for: reminder)
        reminder.snooze(until: date)
        try? context.save()

        scheduleEscalationFromSnooze(for: reminder, resumeAt: date, in: context)
    }

    // MARK: - Notification Handling

    private func handleNotificationResponse(
        reminderId: UUID,
        stepIndex: Int,
        actionIdentifier: String
    ) {
        // This will be called from the app to handle the response
        // The actual context and reminder lookup needs to happen in the view/app layer
        NotificationCenter.default.post(
            name: .processReminderAction,
            object: nil,
            userInfo: [
                "reminderId": reminderId,
                "stepIndex": stepIndex,
                "actionIdentifier": actionIdentifier
            ]
        )
    }
}

extension Notification.Name {
    static let processReminderAction = Notification.Name("processReminderAction")
}
