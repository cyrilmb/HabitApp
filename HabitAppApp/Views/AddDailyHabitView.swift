//
//  AddDailyHabitView.swift
//  HabitTracker
//
//  Sheet for creating a new daily habit
//

import SwiftUI

struct AddDailyHabitView: View {
    @Environment(\.dismiss) var dismiss
    @State private var habitName = ""
    @State private var selectedIcon = "checkmark"
    @State private var selectedColor = "#007AFF"

    let existingCount: Int
    let onSave: (DailyHabit) -> Void

    private let iconOptions = [
        "checkmark", "moon.fill", "phone.fill", "book.fill",
        "figure.walk", "heart.fill", "leaf.fill", "cup.and.saucer.fill",
        "paintbrush.fill", "music.note", "pencil", "star.fill"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Habit Name", text: $habitName)
                        .autocapitalization(.words)
                } header: {
                    Text("Name")
                }

                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 52))], spacing: 12) {
                        ForEach(iconOptions, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.title2)
                                .frame(width: 52, height: 52)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedIcon == icon ? Color.accentColor.opacity(0.2) : Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(selectedIcon == icon ? Color.accentColor : Color.clear, lineWidth: 2)
                                )
                                .onTapGesture {
                                    selectedIcon = icon
                                }
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Icon")
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
            }
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveHabit() }
                        .disabled(habitName.isEmpty)
                }
            }
        }
    }

    private func saveHabit() {
        let habit = DailyHabit(
            userId: FirebaseService.shared.userId,
            name: habitName,
            icon: selectedIcon,
            colorHex: selectedColor,
            sortOrder: existingCount,
            createdAt: Date()
        )
        onSave(habit)
        dismiss()
    }
}
