//
//  DosageEntryView.swift
//  HabitTracker
//
//  Dosage entry view for substance logging
//

import SwiftUI

struct DosageEntryView: View {
    let category: DrugCategory
    let method: String

    @Environment(\.dismiss) var dismiss
    @State private var dosage: String = ""
    @State private var timestamp: Date = Date()
    @State private var notes: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Substance")
                    Spacer()
                    Text(category.name)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Method")
                    Spacer()
                    Text(method)
                        .foregroundColor(.secondary)
                }
            }

            Section {
                HStack {
                    TextField("Amount (optional)", text: $dosage)
                        .keyboardType(.decimalPad)

                    if let unit = category.defaultDosageUnit {
                        Text(unit)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Dosage")
            } footer: {
                if let unit = category.defaultDosageUnit {
                    Text("Enter amount in \(unit)")
                }
            }

            Section {
                DatePicker("When", selection: $timestamp, displayedComponents: [.date, .hourAndMinute])
            }

            Section {
                TextEditor(text: $notes)
                    .frame(height: 80)
                    .onChange(of: notes) { _, new in
                        if new.count > InputLimits.notes {
                            notes = String(new.prefix(InputLimits.notes))
                        }
                    }
            } header: {
                Text("Notes (Optional)")
            }
        }
        .navigationTitle("Log Details")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: saveDrugLog) {
                HStack {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Save")
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.purple.gradient)
                .cornerRadius(12)
            }
            .disabled(isSaving)
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.systemGroupedBackground))
        }
    }

    private func saveDrugLog() {
        isSaving = true

        let userId = FirebaseService.shared.userId
        let dosageValue = Double(dosage)

        var log = DrugLog(
            userId: userId,
            categoryName: category.name,
            method: method,
            dosage: dosageValue,
            dosageUnit: category.defaultDosageUnit,
            timestamp: timestamp
        )

        log.notes = notes.isEmpty ? nil : notes

        Task {
            do {
                try await FirebaseService.shared.saveDrugLog(log)
                await MainActor.run {
                    isSaving = false
                    SheetManager.shared.dismissAndToast(.substance)
                }
            } catch {
                print("Error saving drug log: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to save log. Please try again."
                    isSaving = false
                }
            }
        }
    }
}
