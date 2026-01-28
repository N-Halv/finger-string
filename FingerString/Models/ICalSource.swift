import Foundation
import SwiftData

@Model
final class ICalSource {
    var id: UUID
    var name: String
    var url: URL
    var lastSyncedAt: Date?
    var isEnabled: Bool
    var syncIntervalMinutes: Int

    // Event IDs that have been overridden with local edits
    var ignoredEventIdsData: Data
    var ignoredEventIds: Set<String> {
        get {
            (try? JSONDecoder().decode(Set<String>.self, from: ignoredEventIdsData)) ?? []
        }
        set {
            ignoredEventIdsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    init(
        id: UUID = UUID(),
        name: String,
        url: URL,
        syncIntervalMinutes: Int = 60,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.lastSyncedAt = nil
        self.isEnabled = isEnabled
        self.syncIntervalMinutes = syncIntervalMinutes
        self.ignoredEventIdsData = Data()
    }

    func markEventAsIgnored(_ eventId: String) {
        var ids = ignoredEventIds
        ids.insert(eventId)
        ignoredEventIds = ids
    }

    func shouldIgnoreEvent(_ eventId: String) -> Bool {
        ignoredEventIds.contains(eventId)
    }
}
