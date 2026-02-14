//
//  EditActivityView.swift
//  HabitTracker
//
//  View for editing existing activity entries
//

import SwiftUI

struct EditActivityView: View {
    @Environment(\.dismiss) var dismiss
    @State var activity: Activity

    let onSave: (Activity) -> Void

    @State private var categoryName: String
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var notes: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(activity: Activity, onSave: @escaping (Activity) -> Void) {
        self._activity = State(initialValue: activity)
        self.onSave = onSave
        self._categoryName = State(initialValue: activity.categoryName)
        self._startTime = State(initialValue: activity.startTime)
        self._endTime = State(initialValue: activity.endTime ?? activity.startTime.addingTimeInterval(activity.duration))
        self._notes = State(initialValue: activity.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Activity")
                        Spacer()
                        Text(categoryName)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Activity Type")
                }

                Section {
                    DatePicker("Start", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("End", selection: $endTime, in: startTime..., displayedComponents: [.date, .hourAndMinute])
                } header: {
                    Text("Duration")
                } footer: {
                    Text("Duration: \(formattedDuration)")
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
            .navigationTitle("Edit Activity")
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
                    .disabled(isSaving)
                }
            }
        }
    }

    private var formattedDuration: String {
        let duration = endTime.timeIntervalSince(startTime)
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }

    private func saveChanges() {
        isSaving = true

        activity.startTime = startTime
        activity.endTime = endTime
        activity.duration = endTime.timeIntervalSince(startTime)
        activity.notes = notes.isEmpty ? nil : notes
        activity.isActive = false
        activity.updatedAt = Date()

        Task {
            do {
                try await FirebaseService.shared.saveActivity(activity)
                await MainActor.run {
                    isSaving = false
                    onSave(activity)
                    dismiss()
                }
            } catch {
                print("Error saving activity: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to save. Please try again."
                    isSaving = false
                }
            }
        }
    }
}

#Preview {
    EditActivityView(activity: Activity(userId: "preview", categoryName: "Exercise")) { _ in }
}
