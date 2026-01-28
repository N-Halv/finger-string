import Foundation

enum ReminderState: String, Codable, CaseIterable {
    case pending    // Not yet triggered
    case active     // Escalation in progress
    case completed  // User marked complete (green)
    case ignored    // User dismissed without completing (red)

    var displayColor: String {
        switch self {
        case .pending: return "gray"
        case .active: return "blue"
        case .completed: return "green"
        case .ignored: return "red"
        }
    }
}

enum SourceType: String, Codable {
    case local
    case iCal
}
