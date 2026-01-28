import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            ReminderListView()
                .tabItem {
                    Label("Reminders", systemImage: "bell.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Reminder.self, EscalationPath.self, ICalSource.self], inMemory: true)
}
