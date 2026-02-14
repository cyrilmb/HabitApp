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

    @State private var categoryName: String = ""
    @State private var categoryNames: [String] = []
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date()
    @State private var notes: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(categoryName)
                            .font(.headline)
                        Text("Completed")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Picker("Activity", selection: $categoryName) {
                    ForEach(categoryNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
            }

            Section {
                HStack {
                    Text("Duration")
                    Spacer()
                    Text(computedDuration)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }

                DatePicker("Started", selection: $startTime, displayedComponents: [.date, .hourAndMinute])

                DatePicker("Ended", selection: $endTime, displayedComponents: [.date, .hourAndMinute])
            } header: {
                Text("Summary")
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
                Text("Notes (Optional)")
            }
        }
        .navigationTitle("Activity Complete")
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
            .disabled(isSaving || categoryName.isEmpty)
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.systemGroupedBackground))
        }
        .onAppear {
            categoryName = activity.categoryName
            startTime = activity.startTime
            endTime = activity.endTime ?? Date()
        }
        .task {
            do {
                let categories = try await FirebaseService.shared.fetchActivityCategories()
                var names = categories.map(\.name)
                if !names.contains(activity.categoryName) {
                    names.insert(activity.categoryName, at: 0)
                }
                categoryNames = names
            } catch {
                categoryNames = [activity.categoryName]
            }
        }
    }

    private var computedDuration: String {
        let seconds = endTime.timeIntervalSince(startTime)
        guard seconds > 0 else { return "0:00" }
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func saveActivity() {
        isSaving = true

        var activityToSave = activity
        activityToSave.categoryName = categoryName
        activityToSave.startTime = startTime
        activityToSave.endTime = endTime
        activityToSave.duration = endTime.timeIntervalSince(startTime)
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
                    errorMessage = "Failed to save activity. Please try again."
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
