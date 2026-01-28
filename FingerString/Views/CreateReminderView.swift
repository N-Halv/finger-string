import SwiftUI
import SwiftData

struct CreateReminderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<EscalationPath> { _ in true })
    private var escalationPaths: [EscalationPath]

    @State private var title = ""
    @State private var descriptionText = ""
    @State private var reminderDate = Date()
    @State private var hasTime = true
    @State private var reminderTime = Date()
    @State private var selectedPath: EscalationPath?
    @State private var showingPathPicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)

                    TextField("Description (optional)", text: $descriptionText, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("When") {
                    DatePicker("Date", selection: $reminderDate, displayedComponents: .date)

                    Toggle("Set Time", isOn: $hasTime)

                    if hasTime {
                        DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                }

                Section("Escalation Path") {
                    Button {
                        showingPathPicker = true
                    } label: {
                        HStack {
                            Text(selectedPath?.name ?? "Select Path")
                                .foregroundStyle(selectedPath == nil ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)

                    if let path = selectedPath {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(path.steps) { step in
                                Text("• \(step.displayDescription)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("New Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveReminder()
                    }
                    .disabled(title.isEmpty || selectedPath == nil)
                }
            }
            .sheet(isPresented: $showingPathPicker) {
                EscalationPathPickerView(selectedPath: $selectedPath)
            }
            .onAppear {
                // Default to Standard path
                if selectedPath == nil {
                    selectedPath = escalationPaths.first { $0.name == "Standard" }
                        ?? escalationPaths.first
                }
            }
        }
    }

    private func saveReminder() {
        let reminder = Reminder(
            title: title,
            descriptionText: descriptionText.isEmpty ? nil : descriptionText,
            reminderDate: reminderDate,
            reminderTime: hasTime ? reminderTime : nil,
            escalationPath: selectedPath
        )

        modelContext.insert(reminder)

        // Schedule escalation if the reminder date is in the future
        if reminder.triggerDate > Date() {
            EscalationEngine.shared.scheduleEscalation(for: reminder, in: modelContext)
        } else {
            // If the time has passed, activate immediately
            reminder.activate()
        }

        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    CreateReminderView()
        .modelContainer(for: [Reminder.self, EscalationPath.self, ICalSource.self], inMemory: true)
}
