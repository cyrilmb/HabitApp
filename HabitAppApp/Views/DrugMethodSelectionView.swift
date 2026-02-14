//
//  DrugMethodSelectionView.swift
//  HabitTracker
//
//  Method selection, method button, and add method views for substance logging
//

import SwiftUI

struct DrugMethodSelectionView: View {
    @State private var category: DrugCategory

    @Environment(\.dismiss) var dismiss
    @State private var showAddMethod = false
    @State private var showEditMethods = false
    @State private var showDosageEntry = false
    @State private var selectedMethod: String?
    @State private var errorMessage: String?

    init(category: DrugCategory) {
        self._category = State(initialValue: category)
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: iconForSubstanceCategory(category.name))
                            .font(.system(size: 50))
                            .foregroundColor(colorForSubstanceCategory(category.name))

                        Text(category.name)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Select method")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)

                    // Method Buttons
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(category.methods, id: \.self) { method in
                            MethodButton(method: method) {
                                selectedMethod = method
                                showDosageEntry = true
                            }
                        }

                        // Add Method Button
                        Button(action: { showAddMethod = true }) {
                            VStack(spacing: 8) {
                                Image(systemName: "plus.circle")
                                    .font(.title)
                                Text("Add Method")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 100)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.green, style: StrokeStyle(lineWidth: 2, dash: [5]))
                            )
                        }
                        .foregroundColor(.green)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Select Method")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showEditMethods = true
                }
            }
        }
        .sheet(isPresented: $showAddMethod, onDismiss: reloadCategory) {
            AddMethodView(category: category)
        }
        .sheet(isPresented: $showEditMethods, onDismiss: reloadCategory) {
            EditMethodsView(category: category) {
                dismiss()
            }
        }
        .navigationDestination(isPresented: $showDosageEntry) {
            if let method = selectedMethod {
                DosageEntryView(category: category, method: method)
            }
        }
    }

    private func reloadCategory() {
        Task {
            do {
                let categories = try await FirebaseService.shared.fetchDrugCategories()
                if let updated = categories.first(where: { $0.id == category.id }) {
                    await MainActor.run {
                        category = updated
                    }
                }
            } catch {
                print("Error reloading category: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to reload. Please try again."
                }
            }
        }
    }
}

struct MethodButton: View {
    let method: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: iconForSubstanceMethod(method))
                    .font(.title)

                Text(method)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
        }
        .buttonStyle(.plain)
    }
}

struct AddMethodView: View {
    let category: DrugCategory

    @Environment(\.dismiss) var dismiss
    @State private var methodName = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Method name", text: $methodName)
                        .autocapitalization(.words)
                        .onChange(of: methodName) { _, new in
                            if new.count > InputLimits.methodName {
                                methodName = String(new.prefix(InputLimits.methodName))
                            }
                        }
                } header: {
                    Text("New Method for \(category.name)")
                } footer: {
                    Text("e.g., Bowl, Bong, Tincture, etc.")
                }
            }
            .navigationTitle("Add Method")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addMethod()
                    }
                    .disabled(methodName.isEmpty || isSaving)
                }
            }
        }
    }

    private func addMethod() {
        isSaving = true

        var updatedCategory = category
        updatedCategory.methods.append(methodName)

        Task {
            do {
                try await FirebaseService.shared.saveDrugCategory(updatedCategory)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Error adding method: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to add method. Please try again."
                    isSaving = false
                }
            }
        }
    }
}
