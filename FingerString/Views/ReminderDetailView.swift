import SwiftUI
import SwiftData

struct ReminderDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var reminder: Reminder

    @State private var isEditing = false
    @State private var showingSnoozeOptions = false
    @State private var editTitle: String = ""
    @State private var editDescription: String = ""
    @State private var editDate: Date = Date()
    @State private var editHasTime: Bool = true
    @State private var editTime: Date = Date()

    var body: some View {
        NavigationStack {
            List {
                // Status Section
                Section {
                    HStack {
                        Text("Status")
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(stateColor)
                                .frame(width: 10, height: 10)
                            Text(reminder.state.rawValue.capitalized)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let snoozedUntil = reminder.snoozedUntil {
                        HStack {
                            Text("Snoozed Until")
                            Spacer()
                            Text(snoozedUntil, style: .time)
                                .foregroundStyle(.orange)
                        }
                    }

                    if let path = reminder.escalationPath {
                        HStack {
                            Text("Escalation")
                            Spacer()
                            Text(path.name)
                                .foregroundStyle(.secondary)
                        }

                        if reminder.isActive {
                            HStack {
                                Text("Current Step")
                                Spacer()
                                Text("\(reminder.currentEscalationStep + 1) of \(path.steps.count)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Details Section
                Section("Details") {
                    if isEditing {
                        TextField("Title", text: $editTitle)
                        TextField("Description", text: $editDescription, axis: .vertical)
                            .lineLimit(3...6)
                    } else {
                        Text(reminder.title)
                            .font(.headline)

                        if let description = reminder.descriptionText, !description.isEmpty {
                            Text(description)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Date/Time Section
                Section("When") {
                    if isEditing {
                        DatePicker("Date", selection: $editDate, displayedComponents: .date)
                        Toggle("Set Time", isOn: $editHasTime)
                        if editHasTime {
                            DatePicker("Time", selection: $editTime, displayedComponents: .hourAndMinute)
                        }
                    } else {
                        HStack {
                            Text("Date")
                            Spacer()
                            Text(reminder.triggerDate, style: .date)
                                .foregroundStyle(.secondary)
                        }

                        if reminder.reminderTime != nil {
                            HStack {
                                Text("Time")
                                Spacer()
                                Text(reminder.triggerDate, style: .time)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Actions Section (only for active reminders)
                if reminder.isActive && !isEditing {
                    Section("Actions") {
                        Button {
                            EscalationEngine.shared.complete(reminder: reminder, in: modelContext)
                            dismiss()
                        } label: {
                            Label("Mark Complete", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }

                        Button {
                            showingSnoozeOptions = true
                        } label: {
                            Label("Snooze", systemImage: "moon.zzz.fill")
                                .foregroundStyle(.orange)
                        }

                        Button {
                            EscalationEngine.shared.ignore(reminder: reminder, in: modelContext)
                            dismiss()
                        } label: {
                            Label("Ignore", systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }

                // Source info
                if reminder.sourceType == .iCal {
                    Section("Source") {
                        HStack {
                            Text("Type")
                            Spacer()
                            Text("iCal Link")
                                .foregroundStyle(.secondary)
                        }

                        if reminder.originalICalEventId != nil {
                            Text("This reminder was edited from its original iCal source")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Reminder" : "Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isEditing ? "Cancel" : "Done") {
                        if isEditing {
                            isEditing = false
                        } else {
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    if isEditing {
                        Button("Save") {
                            saveEdits()
                        }
                        .disabled(editTitle.isEmpty)
                    } else if !reminder.isClosed {
                        Button("Edit") {
                            startEditing()
                        }
                    }
                }
            }
            .confirmationDialog("Snooze", isPresented: $showingSnoozeOptions) {
                ForEach(SnoozeOption.allCases) { option in
                    Button(option.displayName) {
                        EscalationEngine.shared.snooze(
                            reminder: reminder,
                            option: option,
                            in: modelContext
                        )
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var stateColor: Color {
        switch reminder.state {
        case .pending: return .gray
        case .active: return .blue
        case .completed: return .green
        case .ignored: return .red
        }
    }

    private func startEditing() {
        editTitle = reminder.title
        editDescription = reminder.descriptionText ?? ""
        editDate = reminder.reminderDate
        editHasTime = reminder.reminderTime != nil
        editTime = reminder.reminderTime ?? Date()
        isEditing = true
    }

    private func saveEdits() {
        let wasActive = reminder.isActive

        reminder.title = editTitle
        reminder.descriptionText = editDescription.isEmpty ? nil : editDescription
        reminder.reminderDate = editDate
        reminder.reminderTime = editHasTime ? editTime : nil
        reminder.updatedAt = Date()

        // If this was from iCal and we're editing, mark the original as ignored
        if reminder.sourceType == .iCal && reminder.originalICalEventId == nil {
            // Store the original event ID to ignore it in future syncs
            reminder.originalICalEventId = reminder.id.uuidString
        }

        // If the reminder was active, restart escalation
        if wasActive {
            reminder.currentEscalationStep = 0
            EscalationEngine.shared.scheduleEscalation(for: reminder, in: modelContext)
        }

        try? modelContext.save()
        isEditing = false
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Reminder.self, EscalationPath.self, configurations: config)

    let reminder = Reminder(
        title: "Test Reminder",
        descriptionText: "This is a test description",
        reminderDate: Date(),
        reminderTime: Date()
    )
    container.mainContext.insert(reminder)

    return ReminderDetailView(reminder: reminder)
        .modelContainer(container)
}
