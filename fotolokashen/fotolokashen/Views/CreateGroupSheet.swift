import SwiftUI

/// Sheet presented when the user chooses to create a LocationGroup (event/route/story)
/// from a spread-detected set of photos.
///
/// Provides:
/// - Group name input
/// - Type picker (presets + user's custom types + add new)
/// - Optional description
/// - Completion callback with the created group
struct CreateGroupSheet: View {

    // MARK: - Callbacks

    let onGroupCreated: (LocationGroup) -> Void
    let onCancel: () -> Void

    // MARK: - State

    @StateObject private var groupService = LocationGroupService.shared
    @State private var groupName = ""
    @State private var groupDescription = ""
    @State private var selectedType: String = GroupTypePreset.event.rawValue
    @State private var customTypes: [CustomGroupType] = []
    @State private var showAddCustomType = false
    @State private var newCustomTypeName = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var isLoadingTypes = true

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // ── Name ──────────────────────────────────────────────
                Section {
                    TextField("e.g. March on Main Street", text: $groupName)
                        .textContentType(.name)
                } header: {
                    Text("Group Name")
                } footer: {
                    Text("A short name for this event or activity.")
                }

                // ── Type ──────────────────────────────────────────────
                Section {
                    // Preset types
                    ForEach(GroupTypePreset.allCases, id: \.rawValue) { preset in
                        typeRow(
                            name: preset.displayName,
                            icon: preset.icon,
                            value: preset.rawValue,
                            isSelected: selectedType == preset.rawValue
                        )
                    }

                    // Divider between presets and custom
                    if !customTypes.isEmpty {
                        Divider()
                        ForEach(customTypes) { custom in
                            typeRow(
                                name: custom.typeName,
                                icon: "tag",
                                value: custom.typeName,
                                isSelected: selectedType == custom.typeName
                            )
                        }
                    }

                    // Add custom type button
                    Button {
                        showAddCustomType = true
                    } label: {
                        Label("Add Custom Type…", systemImage: "plus.circle")
                            .foregroundStyle(.blue)
                    }
                } header: {
                    Text("Type")
                }

                // ── Description ───────────────────────────────────────
                Section {
                    TextField("Describe this event (optional)", text: $groupDescription, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Description")
                }

                // ── Error ─────────────────────────────────────────────
                if let error = errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await createGroup() }
                    }
                    .disabled(groupName.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                    .bold()
                }
            }
            .alert("Add Custom Type", isPresented: $showAddCustomType) {
                TextField("Type name", text: $newCustomTypeName)
                Button("Add") {
                    Task { await addCustomType() }
                }
                Button("Cancel", role: .cancel) {
                    newCustomTypeName = ""
                }
            } message: {
                Text("Enter a name for your custom group type.")
            }
            .task {
                await loadCustomTypes()
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func typeRow(name: String, icon: String, value: String, isSelected: Bool) -> some View {
        Button {
            selectedType = value
        } label: {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24)
                    .foregroundStyle(isSelected ? .blue : .secondary)
                Text(name)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Actions

    private func loadCustomTypes() async {
        defer { isLoadingTypes = false }
        do {
            let (_, custom) = try await groupService.fetchGroupTypes()
            customTypes = custom
        } catch {
            #if DEBUG
            print("[CreateGroupSheet] Failed to load types: \(error)")
            #endif
        }
    }

    private func addCustomType() async {
        let name = newCustomTypeName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        do {
            let created = try await groupService.createCustomType(name: name)
            customTypes.append(created)
            selectedType = created.typeName
            newCustomTypeName = ""
        } catch {
            errorMessage = "Failed to create custom type: \(error.localizedDescription)"
        }
    }

    private func createGroup() async {
        let name = groupName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        isCreating = true
        errorMessage = nil

        do {
            let group = try await groupService.createGroup(
                name: name,
                type: selectedType,
                description: groupDescription.trimmingCharacters(in: .whitespaces).isEmpty
                    ? nil
                    : groupDescription.trimmingCharacters(in: .whitespaces)
            )

            #if DEBUG
            print("[CreateGroupSheet] ✅ Created group \(group.id): \(group.name)")
            #endif

            onGroupCreated(group)
        } catch {
            errorMessage = "Failed to create group: \(error.localizedDescription)"
            isCreating = false
        }
    }
}

// MARK: - Preview

#Preview {
    CreateGroupSheet(
        onGroupCreated: { group in print("Created: \(group.name)") },
        onCancel: { print("Cancelled") }
    )
}
