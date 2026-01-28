import Foundation
import UserNotifications
import SwiftData
import Combine

final class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    @Published var isAuthorized = false

    // Notification action identifiers
    static let completeActionId = "COMPLETE_ACTION"
    static let ignoreActionId = "IGNORE_ACTION"
    static let snooze1HourActionId = "SNOOZE_1_HOUR_ACTION"
    static let snooze3HoursActionId = "SNOOZE_3_HOURS_ACTION"

    // Notification category identifiers
    static let reminderCategoryId = "REMINDER_CATEGORY"

    // UserInfo keys
    static let reminderIdKey = "reminderId"
    static let escalationStepKey = "escalationStep"
    static let isAlarmKey = "isAlarm"

    private override init() {
        super.init()
        setupNotificationCategories()
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge, .criticalAlert]
        ) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
            }
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }

        UNUserNotificationCenter.current().delegate = self
    }

    private func setupNotificationCategories() {
        let completeAction = UNNotificationAction(
            identifier: Self.completeActionId,
            title: "Complete",
            options: [.foreground]
        )

        let ignoreAction = UNNotificationAction(
            identifier: Self.ignoreActionId,
            title: "Ignore",
            options: [.destructive]
        )

        let snooze1HourAction = UNNotificationAction(
            identifier: Self.snooze1HourActionId,
            title: "Snooze 1 Hour",
            options: []
        )

        let snooze3HoursAction = UNNotificationAction(
            identifier: Self.snooze3HoursActionId,
            title: "Snooze 3 Hours",
            options: []
        )

        let reminderCategory = UNNotificationCategory(
            identifier: Self.reminderCategoryId,
            actions: [completeAction, ignoreAction, snooze1HourAction, snooze3HoursAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        UNUserNotificationCenter.current().setNotificationCategories([reminderCategory])
    }

    // MARK: - Scheduling

    func scheduleNotification(
        for reminder: Reminder,
        at date: Date,
        stepIndex: Int,
        isAlarm: Bool
    ) {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.descriptionText ?? "Tap to view reminder"
        content.categoryIdentifier = Self.reminderCategoryId
        content.userInfo = [
            Self.reminderIdKey: reminder.id.uuidString,
            Self.escalationStepKey: stepIndex,
            Self.isAlarmKey: isAlarm
        ]

        if isAlarm {
            // Time-sensitive notification with loud sound
            content.interruptionLevel = .timeSensitive
            content.sound = .defaultCritical
        } else {
            content.sound = .default
        }

        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let identifier = notificationIdentifier(for: reminder, stepIndex: stepIndex)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }

    func cancelNotifications(for reminder: Reminder) {
        // Remove all pending notifications for this reminder
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiersToRemove = requests
                .filter { $0.identifier.hasPrefix(reminder.id.uuidString) }
                .map { $0.identifier }

            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: identifiersToRemove
            )
        }
    }

    func cancelAllNotifications(for reminderId: UUID) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiersToRemove = requests
                .filter { $0.identifier.hasPrefix(reminderId.uuidString) }
                .map { $0.identifier }

            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: identifiersToRemove
            )
        }
    }

    private func notificationIdentifier(for reminder: Reminder, stepIndex: Int) -> String {
        "\(reminder.id.uuidString)-step-\(stepIndex)-\(UUID().uuidString)"
    }

    // MARK: - Repeating Notifications

    /// Schedule multiple notifications for a repeating step (up to iOS limit)
    func scheduleRepeatingNotifications(
        for reminder: Reminder,
        startingAt date: Date,
        stepIndex: Int,
        intervalMinutes: Int,
        maxCount: Int = 50  // Leave room for other notifications within iOS 64 limit
    ) {
        var currentDate = date
        for _ in 0..<maxCount {
            scheduleNotification(
                for: reminder,
                at: currentDate,
                stepIndex: stepIndex,
                isAlarm: true  // Repeating steps are always alarms
            )
            currentDate = Calendar.current.date(
                byAdding: .minute,
                value: intervalMinutes,
                to: currentDate
            ) ?? currentDate
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Show notification even when app is in foreground
        [.banner, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo

        guard let reminderIdString = userInfo[Self.reminderIdKey] as? String,
              let reminderId = UUID(uuidString: reminderIdString) else {
            return
        }

        let stepIndex = userInfo[Self.escalationStepKey] as? Int ?? 0

        // Post notification for the app to handle
        NotificationCenter.default.post(
            name: .reminderNotificationReceived,
            object: nil,
            userInfo: [
                "reminderId": reminderId,
                "stepIndex": stepIndex,
                "actionIdentifier": response.actionIdentifier
            ]
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let reminderNotificationReceived = Notification.Name("reminderNotificationReceived")
}
