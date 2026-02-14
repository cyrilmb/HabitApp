//
//  EditBiometricView.swift
//  HabitTracker
//
//  View for editing existing biometric entries
//

import SwiftUI

struct EditBiometricView: View {
    @Environment(\.dismiss) var dismiss
    @State var biometric: Biometric
    
    let onSave: (Biometric) -> Void
    
    @State private var value: String
    @State private var timestamp: Date
    @State private var notes: String
    @State private var bedTime: Date
    @State private var wakeTime: Date
    @State private var moodPleasantness: Double
    @State private var moodEnergy: Double
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(biometric: Biometric, onSave: @escaping (Biometric) -> Void) {
        self._biometric = State(initialValue: biometric)
        self.onSave = onSave
        self._notes = State(initialValue: biometric.notes ?? "")
        self._timestamp = State(initialValue: biometric.timestamp)

        if biometric.type == .mood {
            self._moodPleasantness = State(initialValue: biometric.value)
            self._moodEnergy = State(initialValue: biometric.secondaryValue ?? 0)
            self._value = State(initialValue: "")
            self._bedTime = State(initialValue: Date())
            self._wakeTime = State(initialValue: Date())
        } else if biometric.type == .bedTime || biometric.type == .wakeTime {
            self._bedTime = State(initialValue: Date())
            self._wakeTime = State(initialValue: Date())
            self._value = State(initialValue: "")
            self._moodPleasantness = State(initialValue: 0)
            self._moodEnergy = State(initialValue: 0)
        } else {
            self._value = State(initialValue: String(biometric.value))
            self._bedTime = State(initialValue: Date())
            self._wakeTime = State(initialValue: Date())
            self._moodPleasantness = State(initialValue: 0)
            self._moodEnergy = State(initialValue: 0)
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Type")
                        Spacer()
                        Text(biometric.type.rawValue)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Biometric Type")
                }
                
                if biometric.type == .mood {
                    Section {
                        CompactCircumplexGrid(pleasantness: $moodPleasantness, energy: $moodEnergy)
                            .padding(.vertical, 8)
                    } header: {
                        Text("Mood Position")
                    } footer: {
                        Text("Nearest: \(nearestEmotionLabel(pleasantness: moodPleasantness, energy: moodEnergy))")
                    }
                } else if biometric.type != .bedTime && biometric.type != .wakeTime && biometric.type != .sleepDuration {
                    Section {
                        HStack {
                            TextField("Value", text: $value)
                                .keyboardType(.decimalPad)

                            Text(biometric.unit)
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Value")
                    }
                }
                
                if biometric.type == .sleepDuration {
                    Section {
                        HStack {
                            TextField("Hours", text: $value)
                                .keyboardType(.decimalPad)
                            Text("hours")
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Duration")
                    }

                    Section {
                        DatePicker("Date", selection: $timestamp, displayedComponents: [.date])
                    } header: {
                        Text("When")
                    }
                } else if biometric.type == .bedTime || biometric.type == .wakeTime {
                    Section {
                        DatePicker(
                            biometric.type == .bedTime ? "Bed Time" : "Wake Time",
                            selection: $timestamp,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    } header: {
                        Text("When")
                    }
                } else {
                    Section {
                        DatePicker("Date & Time", selection: $timestamp, displayedComponents: [.date, .hourAndMinute])
                    } header: {
                        Text("When")
                    }
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
            .navigationTitle("Edit Biometric")
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
                    .disabled(isSaving || !canSave)
                }
            }
        }
    }
    
    private var canSave: Bool {
        if biometric.type == .mood || biometric.type == .bedTime || biometric.type == .wakeTime {
            return true
        }
        return !value.isEmpty && Double(value) != nil
    }
    
    private func saveChanges() {
        isSaving = true
        
        if biometric.type == .mood {
            biometric.value = moodPleasantness
            biometric.secondaryValue = moodEnergy
        } else if biometric.type == .bedTime || biometric.type == .wakeTime {
            // Value is unused for bed/wake — timestamp holds the actual time
        } else {
            guard let numericValue = Double(value) else {
                isSaving = false
                return
            }
            biometric.value = numericValue
        }
        
        biometric.timestamp = timestamp
        biometric.notes = notes.isEmpty ? nil : notes
        biometric.updatedAt = Date()
        
        Task {
            do {
                try await FirebaseService.shared.saveBiometric(biometric)
                await MainActor.run {
                    isSaving = false
                    onSave(biometric)
                    dismiss()
                }
            } catch {
                print("Error saving biometric: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to save. Please try again."
                    isSaving = false
                }
            }
        }
    }
}

#Preview {
    EditBiometricView(biometric: Biometric(userId: "preview", type: .weight, value: 150, unit: "lbs")) { _ in }
}
