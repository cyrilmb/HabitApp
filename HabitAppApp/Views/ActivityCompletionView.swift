//
//  ActivityCompletionView.swift
//  HabitTracker
//
//  Shown after an activity timer ends. Lets the user review, add notes, and save or discard.
//

import SwiftUI

struct ActivityCompletionView: View {
    @Environment(\.dismiss) var dismiss

    let activity: Activity
    let onSaved: () -> Void
    let onDiscarded: () -> Void

    @State private var notes: String = ""
    @State private var isSaving = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(activity.categoryName)
                            .font(.headline)
                        Text("Completed")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section {
                HStack {
                    Text("Duration")
                    Spacer()
                    Text(activity.formattedDuration)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }

                HStack {
                    Text("Started")
                    Spacer()
                    Text(formatTime(activity.startTime))
                        .foregroundColor(.secondary)
                }

                if let endTime = activity.endTime {
                    HStack {
                        Text("Ended")
                        Spacer()
                        Text(formatTime(endTime))
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Summary")
            }

            Section {
                TextEditor(text: $notes)
                    .frame(height: 100)
            } header: {
                Text("Notes (Optional)")
            }
        }
        .navigationTitle("Activity Complete")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Discard", role: .destructive) {
                    dismiss()
                    onDiscarded()
                }
                .foregroundColor(.red)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: saveActivity) {
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
                .background(Color.blue.gradient)
                .cornerRadius(12)
            }
            .disabled(isSaving)
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.systemGroupedBackground))
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    private func formatTime(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }

    private func saveActivity() {
        isSaving = true

        var activityToSave = activity
        activityToSave.notes = notes.isEmpty ? nil : notes
        activityToSave.isActive = false
        activityToSave.updatedAt = Date()

        Task {
            do {
                try await FirebaseService.shared.saveActivity(activityToSave)
                await MainActor.run {
                    isSaving = false
                    onSaved()
                    dismiss()
                }
            } catch {
                print("Error saving activity: \(error)")
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ActivityCompletionView(
            activity: Activity(userId: "preview", categoryName: "Exercise"),
            onSaved: {},
            onDiscarded: {}
        )
    }
}
