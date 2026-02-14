//
//  CreateActivityCategoryView.swift
//  HabitTracker
//
//  View for creating a new activity category
//

import SwiftUI

struct CreateCategoryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var categoryName = ""
    @State private var selectedColor = "#007AFF"
    @State private var notificationEnabled = false
    @State private var notificationInterval: TimeInterval = 300 // 5 minutes default
    @State private var customMinutes: String = ""

    let onSave: (ActivityCategory) -> Void

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
            }
            .navigationTitle("New Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCategory()
                    }
                    .disabled(categoryName.isEmpty)
                }
            }
        }
    }

    private func saveCategory() {
        let userId = FirebaseService.shared.userId
        let actualInterval: TimeInterval? = {
            guard notificationEnabled else { return nil }
            if notificationInterval == -1 {
                guard let mins = Double(customMinutes), mins > 0 else { return nil }
                return mins * 60
            }
            return notificationInterval
        }()
        let category = ActivityCategory(
            userId: userId,
            name: categoryName,
            colorHex: selectedColor,
            notificationInterval: actualInterval
        )
        onSave(category)
        dismiss()
    }
}
