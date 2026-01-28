import Foundation

enum NotificationType: String, Codable, CaseIterable {
    case push   // Standard push notification
    case alarm  // Time-sensitive notification with loud sound

    var displayName: String {
        switch self {
        case .push: return "Push Notification"
        case .alarm: return "Alarm"
        }
    }
}
