import SwiftUI
import SwiftData

@main
struct FingerStringApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([
                Reminder.self,
                EscalationPath.self,
                ICalSource.self
            ])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await seedPresetPaths()
                }
                .onAppear {
                    NotificationManager.shared.requestAuthorization()
                }
        }
        .modelContainer(modelContainer)
    }

    @MainActor
    private func seedPresetPaths() async {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<EscalationPath>(
            predicate: #Predicate { $0.isPreset == true }
        )

        do {
            let existingPresets = try context.fetch(descriptor)
            if existingPresets.isEmpty {
                // Add preset paths
                for preset in EscalationPath.presets {
                    context.insert(preset)
                }
                try context.save()
            }
        } catch {
            print("Failed to seed preset paths: \(error)")
        }
    }
}

