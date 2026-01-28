import SwiftUI
import SwiftData

struct EscalationPathPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \EscalationPath.name) private var paths: [EscalationPath]

    @Binding var selectedPath: EscalationPath?

    @State private var showingCreateCustom = false

    var body: some View {
        NavigationStack {
            List {
                Section("Presets") {
                    ForEach(presetPaths) { path in
                        PathRowView(path: path, isSelected: selectedPath?.id == path.id) {
                            selectedPath = path
                            dismiss()
                        }
                    }
                }

                if !customPaths.isEmpty {
                    Section("Custom") {
                        ForEach(customPaths) { path in
                            PathRowView(path: path, isSelected: selectedPath?.id == path.id) {
                                selectedPath = path
                                dismiss()
                            }
                        }
                        .onDelete(perform: deleteCustomPaths)
                    }
                }

                Section {
                    Button {
                        showingCreateCustom = true
                    } label: {
                        Label("Create Custom Path", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle("Escalation Path")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingCreateCustom) {
                CreateEscalationPathView { newPath in
                    selectedPath = newPath
                    dismiss()
                }
            }
        }
    }

    private var presetPaths: [EscalationPath] {
        paths.filter { $0.isPreset }
    }

    private var customPaths: [EscalationPath] {
        paths.filter { !$0.isPreset }
    }

    private func deleteCustomPaths(at offsets: IndexSet) {
        for index in offsets {
            let path = customPaths[index]
            modelContext.delete(path)
        }
    }
}

struct PathRowView: View {
    let path: EscalationPath
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(path.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    ForEach(path.steps.prefix(3)) { step in
                        Text("• \(step.displayDescription)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if path.steps.count > 3 {
                        Text("• ... and \(path.steps.count - 3) more")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct CreateEscalationPathView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let onSave: (EscalationPath) -> Void

    @State private var name = ""
    @State private var steps: [EscalationStep] = [
        EscalationStep(type: .push, delayMinutes: 0)
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Path Name", text: $name)
                }

                Section("Steps") {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        StepEditorRow(step: $steps[index], stepIndex: index)
                    }
                    .onDelete(perform: deleteSteps)

                    Button {
                        addStep()
                    } label: {
                        Label("Add Step", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Custom Path")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePath()
                    }
                    .disabled(name.isEmpty || steps.isEmpty)
                }
            }
        }
    }

    private func addStep() {
        let lastDelay = steps.last?.delayMinutes ?? 0
        steps.append(EscalationStep(type: .push, delayMinutes: lastDelay + 60))
    }

    private func deleteSteps(at offsets: IndexSet) {
        steps.remove(atOffsets: offsets)
    }

    private func savePath() {
        let path = EscalationPath(name: name, steps: steps, isPreset: false)
        modelContext.insert(path)
        try? modelContext.save()
        onSave(path)
        dismiss()
    }
}

struct StepEditorRow: View {
    @Binding var step: EscalationStep
    let stepIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Step \(stepIndex + 1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Picker("Type", selection: $step.type) {
                ForEach(NotificationType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }

            Stepper("After \(step.delayMinutes) min", value: $step.delayMinutes, in: 0...1440, step: 15)

            Toggle("Repeat", isOn: Binding(
                get: { step.repeatInterval != nil },
                set: { step.repeatInterval = $0 ? 30 : nil }
            ))

            if let interval = step.repeatInterval {
                Stepper(
                    "Every \(interval) min",
                    value: Binding(
                        get: { interval },
                        set: { step.repeatInterval = $0 }
                    ),
                    in: 5...120,
                    step: 5
                )
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    EscalationPathPickerView(selectedPath: .constant(nil))
        .modelContainer(for: [EscalationPath.self], inMemory: true)
}
