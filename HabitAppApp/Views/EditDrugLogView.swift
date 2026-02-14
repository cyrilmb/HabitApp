//
//  EditDrugLogView.swift
//  HabitTracker
//
//  View for editing existing drug/substance log entries
//

import SwiftUI

struct EditDrugLogView: View {
    @Environment(\.dismiss) var dismiss
    @State var drugLog: DrugLog

    let onSave: (DrugLog) -> Void

    @State private var method: String
    @State private var dosage: String
    @State private var timestamp: Date
    @State private var notes: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(drugLog: DrugLog, onSave: @escaping (DrugLog) -> Void) {
        self._drugLog = State(initialValue: drugLog)
        self.onSave = onSave
        self._method = State(initialValue: drugLog.method)
        self._dosage = State(initialValue: drugLog.dosage != nil ? String(drugLog.dosage!) : "")
        self._timestamp = State(initialValue: drugLog.timestamp)
        self._notes = State(initialValue: drugLog.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Substance")
                        Spacer()
                        Text(drugLog.categoryName)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Substance Type")
                }

                Section {
                    TextField("Method", text: $method)
                        .onChange(of: method) { _, new in
                            if new.count > InputLimits.methodName {
                                method = String(new.prefix(InputLimits.methodName))
                            }
                        }

                    HStack {
                        TextField("Dosage", text: $dosage)
                            .keyboardType(.decimalPad)

                        if let unit = drugLog.dosageUnit {
                            Text(unit)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Details")
                }

                Section {
                    DatePicker("Date & Time", selection: $timestamp, displayedComponents: [.date, .hourAndMinute])
                } header: {
                    Text("When")
                }

                Section {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                        .onChange(of: notes) { _, new in
                            if new.count > InputLimits.notes {
                                notes = String(new.prefix(InputLimits.notes))
                            }
                        }
                } header: {
                    Text("Notes")
                }
            }
            .navigationTitle("Edit Substance Log")
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
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(isSaving || method.isEmpty)
                }
            }
        }
    }

    private func saveChanges() {
        isSaving = true

        drugLog.method = method
        drugLog.dosage = Double(dosage)
        drugLog.timestamp = timestamp
        drugLog.notes = notes.isEmpty ? nil : notes
        drugLog.updatedAt = Date()

        Task {
            do {
                try await FirebaseService.shared.saveDrugLog(drugLog)
                await MainActor.run {
                    isSaving = false
                    onSave(drugLog)
                    dismiss()
                }
            } catch {
                print("Error saving drug log: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to save. Please try again."
                    isSaving = false
                }
            }
        }
    }
}

#Preview {
    EditDrugLogView(drugLog: DrugLog(userId: "preview", categoryName: "Alcohol", method: "Beer", dosage: 2, dosageUnit: "drinks")) { _ in }
}
