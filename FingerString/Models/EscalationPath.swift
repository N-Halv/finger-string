import Foundation
import SwiftData

@Model
final class EscalationPath {
    var id: UUID
    var name: String
    var stepsData: Data  // Encoded [EscalationStep]
    var isPreset: Bool

    @Relationship(inverse: \Reminder.escalationPath)
    var reminders: [Reminder]?

    var steps: [EscalationStep] {
        get {
            (try? JSONDecoder().decode([EscalationStep].self, from: stepsData)) ?? []
        }
        set {
            stepsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    init(id: UUID = UUID(), name: String, steps: [EscalationStep], isPreset: Bool = false) {
        self.id = id
        self.name = name
        self.stepsData = (try? JSONEncoder().encode(steps)) ?? Data()
        self.isPreset = isPreset
    }

    // MARK: - Preset Paths

    static func gentlePath() -> EscalationPath {
        EscalationPath(
            name: "Gentle",
            steps: [
                EscalationStep(type: .push, delayMinutes: 0),
                EscalationStep(type: .push, delayMinutes: 120),
                EscalationStep(type: .push, delayMinutes: 240)
            ],
            isPreset: true
        )
    }

    static func standardPath() -> EscalationPath {
        EscalationPath(
            name: "Standard",
            steps: [
                EscalationStep(type: .push, delayMinutes: 0),
                EscalationStep(type: .push, delayMinutes: 60),
                EscalationStep(type: .alarm, delayMinutes: 120),
                EscalationStep(type: .alarm, delayMinutes: 150, repeatInterval: 30)
            ],
            isPreset: true
        )
    }

    static func urgentPath() -> EscalationPath {
        EscalationPath(
            name: "Urgent",
            steps: [
                EscalationStep(type: .push, delayMinutes: 0),
                EscalationStep(type: .alarm, delayMinutes: 15),
                EscalationStep(type: .alarm, delayMinutes: 25, repeatInterval: 10)
            ],
            isPreset: true
        )
    }

    static func nuclearPath() -> EscalationPath {
        EscalationPath(
            name: "Nuclear",
            steps: [
                EscalationStep(type: .alarm, delayMinutes: 0),
                EscalationStep(type: .alarm, delayMinutes: 5, repeatInterval: 5)
            ],
            isPreset: true
        )
    }

    static var presets: [EscalationPath] {
        [gentlePath(), standardPath(), urgentPath(), nuclearPath()]
    }
}
