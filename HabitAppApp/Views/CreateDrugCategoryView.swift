//
//  CreateDrugCategoryView.swift
//  HabitTracker
//
//  View for creating a new substance category with templates
//

import SwiftUI

struct CreateDrugCategoryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var categoryName = ""
    @State private var methods: [String] = [""]
    @State private var dosageUnit = ""

    let onSave: (DrugCategory) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Category Name", text: $categoryName)
                        .autocapitalization(.words)
                        .onChange(of: categoryName) { _, new in
                            if new.count > InputLimits.categoryName {
                                categoryName = String(new.prefix(InputLimits.categoryName))
                            }
                        }
                } header: {
                    Text("Name")
                } footer: {
                    Text("e.g., Alcohol, Cannabis, Caffeine")
                }

                Section {
                    ForEach(methods.indices, id: \.self) { index in
                        HStack {
                            TextField("Method \(index + 1)", text: $methods[index])
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
                    Text("Methods of Use")
                } footer: {
                    Text("e.g., Beer, Wine, Shot (for Alcohol)")
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
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Templates")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                TemplateButton(name: "Alcohol") {
                                    categoryName = "Alcohol"
                                    methods = ["Beer", "Wine", "Shot", "Cocktail"]
                                    dosageUnit = "drinks"
                                }

                                TemplateButton(name: "Cannabis") {
                                    categoryName = "Cannabis"
                                    methods = ["Joint", "Vape", "Edible", "Pipe"]
                                    dosageUnit = "mg"
                                }

                                TemplateButton(name: "Caffeine") {
                                    categoryName = "Caffeine"
                                    methods = ["Coffee", "Tea", "Energy Drink"]
                                    dosageUnit = "mg"
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Substance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCategory()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !categoryName.isEmpty && methods.contains(where: { !$0.isEmpty })
    }

    private func saveCategory() {
        let userId = FirebaseService.shared.userId
        let validMethods = methods.filter { !$0.isEmpty }

        let category = DrugCategory(
            userId: userId,
            name: categoryName,
            methods: validMethods,
            defaultDosageUnit: dosageUnit.isEmpty ? nil : dosageUnit
        )

        onSave(category)
        dismiss()
    }
}

struct TemplateButton: View {
    let name: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.purple.opacity(0.1))
                .foregroundColor(.purple)
                .cornerRadius(8)
        }
    }
}
