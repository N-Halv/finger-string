import Foundation

struct EscalationStep: Codable, Identifiable, Equatable {
    var id = UUID()
    var type: NotificationType
    var delayMinutes: Int      // Delay from reminder time (cumulative)
    var repeatInterval: Int?   // For repeating steps (in minutes), nil = no repeat

    var displayDescription: String {
        if delayMinutes == 0 {
            return "\(type.displayName) at reminder time"
        } else if let interval = repeatInterval {
            return "\(type.displayName) every \(interval) min after \(delayMinutes) min"
        } else {
            return "\(type.displayName) after \(delayMinutes) min"
        }
    }
}
