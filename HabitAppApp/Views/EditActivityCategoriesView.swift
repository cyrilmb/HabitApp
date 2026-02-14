//
//  EditActivityCategoriesView.swift
//  HabitTracker
//
//  Views for editing and deleting activity categories
//

import SwiftUI

struct EditCategoriesView: View {
    let categories: [ActivityCategory]
    let onUpdate: () -> Void

    @Environment(\.dismiss) var dismiss
    @State private var selectedCategory: ActivityCategory?
    @State private var showEditSheet = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(categories) { category in
                    Button(action: {
                        selectedCategory = category
                        showEditSheet = true
                    }) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(hex: category.colorHex ?? "#007AFF") ?? .blue)
                                .frame(width: 32, height: 32)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(category.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                if let interval = category.notificationInterval {
                                    Text("Notifications every \(formatInterval(interval))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("No notifications")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Edit Activities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                if let category = selectedCategory {
                    EditCategoryView(category: category) {
                        onUpdate()
                        showEditSheet = false
                    }
                }
            }
        }
    }
}

// MARK: - Edit Single Category View

struct EditCategoryView: View {
    let category: ActivityCategory
    let onSave: () -> Void

    @Environment(\.dismiss) var dismiss
    @State private var categoryName: String
    @State private var selectedColor: String
    @State private var notificationEnabled: Bool
    @State private var notificationInterval: TimeInterval
    @State private var customMinutes: String
    @State private var showDeleteAlert = false
    @State private var deleteAllLogs = false
    @State private var isDeleting = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private static let presetValues: Set<TimeInterval> = [300, 600, 900, 1800, 3600]

    init(category: ActivityCategory, onSave: @escaping () -> Void) {
        self.category = category
        self.onSave = onSave
        self._categoryName = State(initialValue: category.name)
        self._selectedColor = State(initialValue: category.colorHex ?? "#007AFF")
        self._notificationEnabled = State(initialValue: category.notificationInterval != nil)

        if let interval = category.notificationInterval, !Self.presetValues.contains(interval) {
            self._notificationInterval = State(initialValue: -1)
            self._customMinutes = State(initialValue: "\(Int(interval / 60))")
        } else {
            self._notificationInterval = State(initialValue: category.notificationInterval ?? 300)
            self._customMinutes = State(initialValue: "")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Activity Name", text: $categoryName)
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
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(AppConstants.colorOptions, id: \.self) { colorHex in
                            Circle()
                                .fill(Color(hex: colorHex) ?? .blue)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.primary, lineWidth: selectedColor == colorHex ? 3 : 0)
                                )
                                .onTapGesture {
                                    selectedColor = colorHex
                                }
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Color")
                }

                Section {
                    Toggle("Enable Notifications", isOn: $notificationEnabled)

                    if notificationEnabled {
                        Picker("Interval", selection: $notificationInterval) {
                            ForEach(AppConstants.notificationOptions, id: \.1) { option in
                                Text(option.0).tag(option.1)
                            }
                        }

                        if notificationInterval == -1 {
                            HStack {
                                TextField("Minutes", text: $customMinutes)
                                    .keyboardType(.numberPad)
                                Text("minutes")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Timer Notifications")
                } footer: {
                    Text("Get reminded while your timer is running")
                }

                Section {
                    Toggle("Delete all past logs", isOn: $deleteAllLogs)
                        .foregroundColor(.red)

                    Button(role: .destructive, action: { showDeleteAlert = true }) {
                        HStack {
                            Spacer()
                            if isDeleting {
                                ProgressView()
                            } else {
                                Text("Delete Activity")
                            }
                            Spacer()
                        }
                    }
                    .disabled(isDeleting)
                } header: {
                    Text("Danger Zone")
                } footer: {
                    if deleteAllLogs {
                        Text("⚠️ This will permanently delete this activity category and all \(category.name) logs")
                    } else {
                        Text("This will delete the activity category but keep past logs")
                    }
                }
            }
            .navigationTitle("Edit Activity")
            .navigationBarTitleDisplayMode(.inline)
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
                    .disabled(categoryName.isEmpty || isSaving)
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
            .alert("Delete Activity?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteCategory()
                }
            } message: {
                if deleteAllLogs {
                    Text("This will permanently delete \(category.name) and all past logs. This cannot be undone.")
                } else {
                    Text("This will delete \(category.name) but keep past logs.")
                }
            }
        }
    }

    private func saveChanges() {
        isSaving = true

        let actualInterval: TimeInterval? = {
            guard notificationEnabled else { return nil }
            if notificationInterval == -1 {
                guard let mins = Double(customMinutes), mins > 0 else { return nil }
                return mins * 60
            }
            return notificationInterval
        }()

        var updatedCategory = category
        updatedCategory.name = categoryName
        updatedCategory.colorHex = selectedColor
        updatedCategory.notificationInterval = actualInterval

        Task {
            do {
                try await FirebaseService.shared.saveActivityCategory(updatedCategory)
                await MainActor.run {
                    isSaving = false
                    onSave()
                    dismiss()
                }
            } catch {
                print("Error saving category: \(error)")
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
                // Delete category
                if let categoryId = category.id {
                    try await FirebaseService.shared.deleteActivityCategory(categoryId)
                }

                // Delete all logs if requested
                if deleteAllLogs {
                    try await FirebaseService.shared.deleteActivitiesByCategory(category.name)
                }

                await MainActor.run {
                    isDeleting = false
                    onSave()
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
