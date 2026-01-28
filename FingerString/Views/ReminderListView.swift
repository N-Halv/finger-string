import SwiftUI
import SwiftData

struct ReminderListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Reminder.reminderDate) private var reminders: [Reminder]
    @State private var showingCreateSheet = false
    @State private var selectedReminder: Reminder?

    var body: some View {
        NavigationStack {
            List {
                if activeReminders.isEmpty && pendingReminders.isEmpty && closedReminders.isEmpty {
                    ContentUnavailableView(
                        "No Reminders",
                        systemImage: "bell.slash",
                        description: Text("Tap + to create your first reminder")
                    )
                } else {
                    if !activeReminders.isEmpty {
                        Section("Active") {
                            ForEach(activeReminders) { reminder in
                                ReminderRowView(reminder: reminder)
                                    .onTapGesture {
                                        selectedReminder = reminder
                                    }
                            }
                            .onDelete { indexSet in
                                deleteReminders(at: indexSet, from: activeReminders)
                            }
                        }
                    }

                    if !pendingReminders.isEmpty {
                        Section("Upcoming") {
                            ForEach(pendingReminders) { reminder in
                                ReminderRowView(reminder: reminder)
                                    .onTapGesture {
                                        selectedReminder = reminder
                                    }
                            }
                            .onDelete { indexSet in
                                deleteReminders(at: indexSet, from: pendingReminders)
                            }
                        }
                    }

                    if !closedReminders.isEmpty {
                        Section("Closed") {
                            ForEach(closedReminders) { reminder in
                                ReminderRowView(reminder: reminder)
                                    .onTapGesture {
                                        selectedReminder = reminder
                                    }
                            }
                            .onDelete { indexSet in
                                deleteReminders(at: indexSet, from: closedReminders)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Finger String")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                CreateReminderView()
            }
            .sheet(item: $selectedReminder) { reminder in
                ReminderDetailView(reminder: reminder)
            }
        }
    }

    private var activeReminders: [Reminder] {
        reminders.filter { $0.state == .active }
    }

    private var pendingReminders: [Reminder] {
        reminders.filter { $0.state == .pending }
    }

    private var closedReminders: [Reminder] {
        reminders.filter { $0.state == .completed || $0.state == .ignored }
    }

    private func deleteReminders(at offsets: IndexSet, from list: [Reminder]) {
        for index in offsets {
            let reminder = list[index]
            NotificationManager.shared.cancelNotifications(for: reminder)
            modelContext.delete(reminder)
        }
    }
}

struct ReminderRowView: View {
    let reminder: Reminder

    var body: some View {
        HStack {
            Circle()
                .fill(stateColor)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title)
                    .font(.headline)
                    .strikethrough(reminder.isClosed)

                HStack {
                    Text(reminder.triggerDate, style: .date)
                    if reminder.reminderTime != nil {
                        Text(reminder.triggerDate, style: .time)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let path = reminder.escalationPath {
                    Text(path.name)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if reminder.snoozedUntil != nil {
                Image(systemName: "moon.zzz.fill")
                    .foregroundStyle(.orange)
            }

            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }

    private var stateColor: Color {
        switch reminder.state {
        case .pending: return .gray
        case .active: return .blue
        case .completed: return .green
        case .ignored: return .red
        }
    }
}

#Preview {
    ReminderListView()
        .modelContainer(for: [Reminder.self, EscalationPath.self, ICalSource.self], inMemory: true)
}
