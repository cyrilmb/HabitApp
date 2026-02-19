//
//  EditBiometricTypesView.swift
//  HabitTracker
//
//  View for reordering and toggling biometric types
//

import SwiftUI

struct EditBiometricTypesView: View {
    @Environment(\.dismiss) var dismiss
    @State private var enabledTypes: [BiometricType]
    @State private var isSaving = false

    let onSave: () -> Void

    init(enabledTypes: [BiometricType], onSave: @escaping () -> Void) {
        self._enabledTypes = State(initialValue: enabledTypes)
        self.onSave = onSave
    }

    private var disabledTypes: [BiometricType] {
        BiometricType.allCases.filter { !enabledTypes.contains($0) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Enabled") {
                    ForEach(enabledTypes, id: \.self) { type in
                        HStack {
                            Image(systemName: type.icon)
                                .foregroundColor(.accentColor)
                            Text(type.rawValue)
                            Spacer()
                        }
                    }
                    .onMove { enabledTypes.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { enabledTypes.remove(atOffsets: $0) }
                }

                if !disabledTypes.isEmpty {
                    Section("Available") {
                        ForEach(disabledTypes, id: \.self) { type in
                            Button {
                                enabledTypes.append(type)
                            } label: {
                                HStack {
                                    Image(systemName: type.icon)
                                    Text(type.rawValue)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Edit Metrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(isSaving || enabledTypes.isEmpty)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        Task {
            try? await FirebaseService.shared.saveBiometricTypePreferences(enabledTypes)
            await MainActor.run {
                onSave()
                dismiss()
            }
        }
    }
}
