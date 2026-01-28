import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ICalSource.name) private var iCalSources: [ICalSource]
    @Query private var escalationPaths: [EscalationPath]

    @State private var showingAddSource = false
    @State private var selectedSource: ICalSource?

    private var escalationPathCount: Int {
        escalationPaths.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Notifications")
                        Spacer()
                        Text(NotificationManager.shared.isAuthorized ? "Enabled" : "Disabled")
                            .foregroundStyle(NotificationManager.shared.isAuthorized ? .green : .red)
                    }

                    if !NotificationManager.shared.isAuthorized {
                        Button("Enable Notifications") {
                            NotificationManager.shared.requestAuthorization()
                        }
                    }
                } header: {
                    Text("Permissions")
                }

                Section {
                    if iCalSources.isEmpty {
                        Text("No iCal sources added")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(iCalSources) { source in
                            ICalSourceRow(source: source)
                                .onTapGesture {
                                    selectedSource = source
                                }
                        }
                        .onDelete(perform: deleteSources)
                    }

                    Button {
                        showingAddSource = true
                    } label: {
                        Label("Add iCal Source", systemImage: "plus")
                    }
                } header: {
                    Text("iCal Sources")
                } footer: {
                    Text("Import reminders from iCal/ICS calendar links")
                }

                Section {
                    NavigationLink {
                        EscalationPathsListView()
                    } label: {
                        HStack {
                            Text("Escalation Paths")
                            Spacer()
                            Text("\(escalationPathCount)")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Escalation Paths")
                } footer: {
                    Text("Manage how reminders escalate from notifications to alarms")
                }

                Section {
                    Link(destination: URL(string: "https://github.com")!) {
                        HStack {
                            Text("GitHub")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("About")
                } footer: {
                    Text("Finger String v1.0.0")
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingAddSource) {
                AddICalSourceView()
            }
            .sheet(item: $selectedSource) { source in
                ICalSourceDetailView(source: source)
            }
        }
    }

    private func deleteSources(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(iCalSources[index])
        }
    }
}

struct ICalSourceRow: View {
    let source: ICalSource

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(source.name)
                    .font(.headline)

                Text(source.url.absoluteString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let lastSync = source.lastSyncedAt {
                    Text("Last synced: \(lastSync, style: .relative) ago")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Toggle("", isOn: .constant(source.isEnabled))
                .labelsHidden()
        }
    }
}

struct AddICalSourceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var urlString = ""
    @State private var syncInterval = 60
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Source Details") {
                    TextField("Name", text: $name)
                    TextField("iCal URL", text: $urlString)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }

                Section("Sync Settings") {
                    Picker("Sync Interval", selection: $syncInterval) {
                        Text("Every 15 minutes").tag(15)
                        Text("Every 30 minutes").tag(30)
                        Text("Every hour").tag(60)
                        Text("Every 2 hours").tag(120)
                        Text("Every 6 hours").tag(360)
                        Text("Daily").tag(1440)
                    }
                }
            }
            .navigationTitle("Add iCal Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addSource()
                    }
                    .disabled(name.isEmpty || urlString.isEmpty)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func addSource() {
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL format"
            showingError = true
            return
        }

        let source = ICalSource(
            name: name,
            url: url,
            syncIntervalMinutes: syncInterval
        )

        modelContext.insert(source)
        try? modelContext.save()

        // Trigger initial sync
        Task {
            await ICalSyncService.shared.syncSource(source, in: modelContext)
        }

        dismiss()
    }
}

struct ICalSourceDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var source: ICalSource

    @State private var isSyncing = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $source.name)

                    Text(source.url.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Status") {
                    Toggle("Enabled", isOn: $source.isEnabled)

                    if let lastSync = source.lastSyncedAt {
                        HStack {
                            Text("Last Synced")
                            Spacer()
                            Text(lastSync, style: .relative)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        syncNow()
                    } label: {
                        HStack {
                            Text("Sync Now")
                            if isSyncing {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isSyncing)
                }

                Section {
                    Text("\(source.ignoredEventIds.count) events overridden locally")
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Local Overrides")
                } footer: {
                    Text("When you edit an event from this source, it creates a local copy and ignores the original")
                }
            }
            .navigationTitle("iCal Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
    }

    private func syncNow() {
        isSyncing = true
        Task {
            await ICalSyncService.shared.syncSource(source, in: modelContext)
            isSyncing = false
        }
    }
}

// MARK: - Escalation Paths List

struct EscalationPathsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EscalationPath.name) private var paths: [EscalationPath]

    @State private var showingCreatePath = false
    @State private var pathToEdit: EscalationPath?

    var body: some View {
        List {
            Section("Presets") {
                ForEach(presetPaths) { path in
                    EscalationPathRow(path: path)
                        .onTapGesture {
                            pathToEdit = path
                        }
                }
            }

            Section("Custom") {
                if customPaths.isEmpty {
                    Text("No custom paths")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(customPaths) { path in
                        EscalationPathRow(path: path)
                            .onTapGesture {
                                pathToEdit = path
                            }
                    }
                    .onDelete(perform: deleteCustomPaths)
                }

                Button {
                    showingCreatePath = true
                } label: {
                    Label("Create Custom Path", systemImage: "plus")
                }
            }
        }
        .navigationTitle("Escalation Paths")
        .sheet(isPresented: $showingCreatePath) {
            CreateEscalationPathView { _ in }
        }
        .sheet(item: $pathToEdit) { path in
            EditEscalationPathView(path: path)
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

struct EscalationPathRow: View {
    let path: EscalationPath

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(path.name)
                    .font(.headline)
                if path.isPreset {
                    Text("Preset")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(0.2))
                        .clipShape(Capsule())
                }
            }

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
        .padding(.vertical, 4)
    }
}

struct EditEscalationPathView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let path: EscalationPath
    let isPreset: Bool

    @State private var name: String
    @State private var steps: [EscalationStep]

    init(path: EscalationPath) {
        self.path = path
        self.isPreset = path.isPreset
        self._name = State(initialValue: path.name)
        self._steps = State(initialValue: path.steps)
    }

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                stepsSection
                presetInfoSection
            }
            .navigationTitle(isPreset ? "View Path" : "Edit Path")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isPreset ? "Done" : "Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePath()
                    }
                    .disabled(name.isEmpty || steps.isEmpty)
                    .opacity(isPreset ? 0 : 1)
                }
            }
        }
    }

    private var nameSection: some View {
        Section("Name") {
            if isPreset {
                Text(name)
                    .foregroundStyle(.secondary)
            } else {
                TextField("Path Name", text: $name)
            }
        }
    }

    private var stepsSection: some View {
        Section("Steps") {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, _ in
                StepEditorRow(step: $steps[index], stepIndex: index)
                    .disabled(isPreset)
            }
            .onDelete(perform: deleteSteps)
            .deleteDisabled(isPreset)

            addStepButton
        }
    }

    @ViewBuilder
    private var addStepButton: some View {
        if !isPreset {
            Button {
                addStep()
            } label: {
                Label("Add Step", systemImage: "plus")
            }
        }
    }

    @ViewBuilder
    private var presetInfoSection: some View {
        if isPreset {
            Section {
                Text("Preset paths cannot be edited. Create a custom path to customize escalation behavior.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        path.name = name
        path.steps = steps
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [ICalSource.self, Reminder.self, EscalationPath.self], inMemory: true)
}
