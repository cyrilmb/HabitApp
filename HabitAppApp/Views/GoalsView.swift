//
//  GoalsView.swift
//  HabitTracker
//
//  Main goals management screen
//

import SwiftUI

struct GoalsView: View {
    @State private var goals: [Goal] = []
    @State private var isLoading = true
    @State private var showCreateGoal = false
    @State private var goalToEdit: Goal?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading goals...")
            } else if goals.isEmpty {
                emptyState
            } else {
                goalsList
            }
        }
        .navigationTitle("Goals")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showCreateGoal = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreateGoal) {
            CreateGoalView { goal in
                Task { await saveAndReload(goal) }
            }
        }
        .sheet(item: $goalToEdit) { goal in
            EditGoalView(goal: goal) { updated in
                Task { await saveAndReload(updated) }
            }
        }
        .task { await loadGoals() }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No Goals Yet")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Tap + to set your first goal")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button(action: { showCreateGoal = true }) {
                Label("Add Goal", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var goalsList: some View {
        List {
            ForEach(GoalCategoryType.allCases, id: \.self) { type in
                let sectionGoals = goals.filter { $0.categoryType == type }
                if !sectionGoals.isEmpty {
                    Section(header: Text(sectionHeader(for: type))) {
                        ForEach(sectionGoals) { goal in
                            GoalRow(goal: goal)
                                .contentShape(Rectangle())
                                .onTapGesture { goalToEdit = goal }
                        }
                        .onDelete { indexSet in
                            Task { await deleteGoals(sectionGoals, at: indexSet) }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Helpers

    private func sectionHeader(for type: GoalCategoryType) -> String {
        switch type {
        case .activity: return "Activities"
        case .substance: return "Substances"
        case .biometric: return "Biometrics"
        }
    }

    private func loadGoals() async {
        do {
            goals = try await FirebaseService.shared.fetchGoals()
            isLoading = false
        } catch {
            print("Error loading goals: \(error)")
            isLoading = false
        }
    }

    private func saveAndReload(_ goal: Goal) async {
        do {
            try await FirebaseService.shared.saveGoal(goal)
            await loadGoals()
        } catch {
            print("Error saving goal: \(error)")
        }
    }

    private func deleteGoals(_ sectionGoals: [Goal], at offsets: IndexSet) async {
        for index in offsets {
            let goal = sectionGoals[index]
            guard let id = goal.id else { continue }
            do {
                try await FirebaseService.shared.deleteGoal(id)
            } catch {
                print("Error deleting goal: \(error)")
            }
        }
        await loadGoals()
    }
}

// MARK: - Goal Row

struct GoalRow: View {
    let goal: Goal

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconForType)
                .font(.title3)
                .foregroundColor(colorForType)
                .frame(width: 36, height: 36)
                .background(colorForType.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(goal.categoryName)
                    .font(.headline)
                HStack(spacing: 6) {
                    Text(kindBadge)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(goal.kind == .target ? Color.green : Color.orange)
                        .clipShape(Capsule())

                    Text(goalDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if let period = goal.period {
                Text(period.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("One-time")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var iconForType: String {
        switch goal.categoryType {
        case .activity: return "timer"
        case .substance: return "pill"
        case .biometric: return "heart.text.square"
        }
    }

    private var colorForType: Color {
        switch goal.categoryType {
        case .activity: return .blue
        case .substance: return .purple
        case .biometric: return .red
        }
    }

    private var kindBadge: String {
        goal.kind == .target ? "Target" : "Limit"
    }

    private var goalDescription: String {
        let comparisonText: String
        switch goal.comparison {
        case .atLeast: comparisonText = "At least"
        case .atMost: comparisonText = "At most"
        case .exactly: comparisonText = "Exactly"
        }

        let valueText: String
        if goal.value == floor(goal.value) {
            valueText = String(format: "%.0f", goal.value)
        } else {
            valueText = String(format: "%.1f", goal.value)
        }

        return "\(comparisonText) \(valueText) \(goal.unit)"
    }
}
