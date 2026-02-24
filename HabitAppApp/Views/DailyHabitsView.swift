//
//  DailyHabitsView.swift
//  HabitTracker
//
//  Dedicated checklist view for daily habits with To Do / Completed sections
//

import SwiftUI

struct DailyHabitsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var firebaseService = FirebaseService.shared
    @State private var dailyHabits: [DailyHabit] = []
    @State private var completedHabitIds: Set<String> = []
    @State private var showAddHabitSheet = false

    private var todoHabits: [DailyHabit] {
        dailyHabits.filter { guard let id = $0.id else { return true }; return !completedHabitIds.contains(id) }
    }

    private var completedHabits: [DailyHabit] {
        dailyHabits.filter { guard let id = $0.id else { return false }; return completedHabitIds.contains(id) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !todoHabits.isEmpty {
                    Section {
                        ForEach(todoHabits) { habit in
                            HabitChecklistRow(habit: habit, isCompleted: false) {
                                toggleHabit(habit)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { deleteHabit(habit) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowSeparator(.hidden)
                        }
                    } header: {
                        Text("To Do (\(todoHabits.count))")
                    }
                }

                if !completedHabits.isEmpty {
                    Section {
                        ForEach(completedHabits) { habit in
                            HabitChecklistRow(habit: habit, isCompleted: true) {
                                toggleHabit(habit)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { deleteHabit(habit) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowSeparator(.hidden)
                        }
                    } header: {
                        Text("Completed (\(completedHabits.count))")
                    }
                }

                if dailyHabits.isEmpty {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "checklist")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("No habits yet")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Tap + to add your first daily habit")
                                .font(.subheadline)
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                        .listRowSeparator(.hidden)
                    }
                }
            }
            .listStyle(.plain)
            .animation(.easeInOut(duration: 0.3), value: completedHabitIds)
            .navigationTitle("Daily Habits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddHabitSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add daily habit")
                }
            }
            .sheet(isPresented: $showAddHabitSheet) {
                AddDailyHabitView(existingCount: dailyHabits.count) { habit in
                    Task {
                        try? await FirebaseService.shared.saveDailyHabit(habit)
                        await loadDailyHabits()
                    }
                }
            }
            .task {
                await loadDailyHabits()
            }
        }
    }

    private func loadDailyHabits() async {
        guard firebaseService.isReady else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())

        do {
            dailyHabits = try await FirebaseService.shared.fetchDailyHabits()
            let completions = try await FirebaseService.shared.fetchHabitCompletions(for: todayString)
            completedHabitIds = Set(completions.map { $0.habitId })
        } catch {
            // Silently handle — user will see empty state
        }
    }

    private func toggleHabit(_ habit: DailyHabit) {
        guard let habitId = habit.id else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())

        if completedHabitIds.contains(habitId) {
            completedHabitIds.remove(habitId)
        } else {
            completedHabitIds.insert(habitId)
        }

        Task {
            do {
                let isCompleted = try await FirebaseService.shared.toggleHabitCompletion(habit: habit, date: todayString)
                if isCompleted {
                    completedHabitIds.insert(habitId)
                } else {
                    completedHabitIds.remove(habitId)
                }
            } catch {
                // Revert on failure
                if completedHabitIds.contains(habitId) {
                    completedHabitIds.remove(habitId)
                } else {
                    completedHabitIds.insert(habitId)
                }
            }
        }
    }

    private func deleteHabit(_ habit: DailyHabit) {
        guard let habitId = habit.id else { return }
        withAnimation {
            dailyHabits.removeAll { $0.id == habitId }
            completedHabitIds.remove(habitId)
        }
        Task {
            try? await FirebaseService.shared.deleteDailyHabit(habitId)
        }
    }
}

struct HabitChecklistRow: View {
    let habit: DailyHabit
    let isCompleted: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                Image(systemName: habit.icon)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background((Color(hex: habit.colorHex) ?? .blue).gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Text(habit.name)
                    .font(.headline)
                    .foregroundColor(isCompleted ? .secondary : .primary)
                    .strikethrough(isCompleted, color: .secondary)

                Spacer()

                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isCompleted ? .green : .secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isCompleted ? Color.green.opacity(0.08) : Color(UIColor.secondarySystemBackground))
            )
            .opacity(isCompleted ? 0.85 : 1.0)
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
        .accessibilityLabel("\(habit.name), \(isCompleted ? "completed" : "not completed")")
        .accessibilityHint("Double tap to toggle completion")
    }
}
