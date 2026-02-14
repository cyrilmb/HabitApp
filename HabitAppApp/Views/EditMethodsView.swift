//
//  EditMethodsView.swift
//  HabitTracker
//
//  View for editing substance methods, dosage unit, and deleting categories
//

import SwiftUI

struct EditMethodsView: View {
    let category: DrugCategory
    let onDeleted: (() -> Void)?

    @Environment(\.dismiss) var dismiss
    @State private var categoryName: String
    @State private var dosageUnit: String
    @State private var methods: [String]
    @State private var isSaving = false
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    init(category: DrugCategory, onDeleted: (() -> Void)? = nil) {
        self.category = category
        self.onDeleted = onDeleted
        self._categoryName = State(initialValue: category.name)
        self._dosageUnit = State(initialValue: category.defaultDosageUnit ?? "")
        self._methods = State(initialValue: category.methods)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Substance Name", text: $categoryName)
                        .autocapitalization(.words)
                        .onChange(of: categoryName) { _, new in
                            if new.count > InputLimits.categoryName {
                                categoryName = String(new.prefix(InputLimits.categoryName))
                            }
                        }
                } header: {
                    Text("Name")
                }

                Section {
                    TextField("Unit (optional)", text: $dosageUnit)
                        .onChange(of: dosageUnit) { _, new in
                            if new.count > InputLimits.dosageUnit {
                                dosageUnit = String(new.prefix(InputLimits.dosageUnit))
                            }
                        }
                } header: {
                    Text("Dosage Unit")
                } footer: {
                    Text("e.g., drinks, mg, oz")
                }

                Section {
                    ForEach(methods.indices, id: \.self) { index in
                        HStack {
                            TextField("Method name", text: $methods[index])
                                .autocapitalization(.words)
                                .onChange(of: methods[index]) { _, new in
                                    if new.count > InputLimits.methodName {
                                        methods[index] = String(new.prefix(InputLimits.methodName))
                                    }
                                }

                            if methods.count > 1 {
                                Button(action: { methods.remove(at: index) }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }

                    Button(action: { methods.append("") }) {
                        Label("Add Method", systemImage: "plus.circle.fill")
                            .foregroundColor(.green)
                    }
                } header: {
                    Text("Methods")
                }

                Section {
                    Button(role: .destructive, action: { showDeleteAlert = true }) {
                        HStack {
                            Spacer()
                            if isDeleting {
                                ProgressView()
                            } else {
                                Text("Delete Substance")
                            }
                            Spacer()
                        }
                    }
                    .disabled(isDeleting)
                } header: {
                    Text("Danger Zone")
                }
            }
            .navigationTitle("Edit Substance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(isSaving || categoryName.isEmpty || methods.filter({ !$0.isEmpty }).isEmpty)
                }
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .alert("Delete Substance?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteCategory()
                }
            } message: {
                Text("This will permanently delete \(category.name). Past logs will be kept.")
            }
        }
    }

    private func saveChanges() {
        isSaving = true

        var updatedCategory = category
        updatedCategory.name = categoryName
        updatedCategory.defaultDosageUnit = dosageUnit.isEmpty ? nil : dosageUnit
        updatedCategory.methods = methods.filter { !$0.isEmpty }

        Task {
            do {
                try await FirebaseService.shared.saveDrugCategory(updatedCategory)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Error saving methods: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to save. Please try again."
                    isSaving = false
                }
            }
        }
    }

    private func deleteCategory() {
        isDeleting = true

        Task {
            do {
                if let categoryId = category.id {
                    try await FirebaseService.shared.deleteDrugCategory(categoryId)
                }
                await MainActor.run {
                    isDeleting = false
                    onDeleted?()
                    dismiss()
                }
            } catch {
                print("Error deleting category: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to delete. Please try again."
                    isDeleting = false
                }
            }
        }
    }
}
